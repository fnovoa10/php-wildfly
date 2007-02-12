/*
 * JBoss, the OpenSource J2EE webOS
 *
 * Distributable under LGPL license.
 * See terms of license at gnu.org.
 */

/* Ignore Microsoft's interpretation of secure development
 * and the POSIX string handling API
 */
#if defined(_MSC_VER) && _MSC_VER >= 1400
#ifndef _CRT_SECURE_NO_DEPRECATE
#define _CRT_SECURE_NO_DEPRECATE
#endif
#pragma warning(disable: 4996)
#endif

#include "php.h"
#include "php_main.h"
#include "SAPI.h"
#include "php_globals.h"
#include "ext/standard/info.h"
#include "ext/standard/head.h"
#include "ext/standard/basic_functions.h"
#include "php_variables.h"
#include "php_ini.h"

#include "zend.h"
#include "zend_compile.h"
#include "zend_execute.h"
#include "zend_highlight.h"

#ifdef PHP_WIN32
# include <process.h>
#endif

#include <jni.h>

#define JPHP_IMPLEMENT_CALL(RT, CL, FN)  \
    JNIEXPORT RT JNICALL Java_org_apache_catalina_servlets_php_##CL##_##FN

#define JPHP_IMPLEMENT_METHOD(RT, FN)    \
    static RT method_##FN

#define JPHP_GETNET_METHOD(FN)  method_##FN

#define JPHP_BEGIN_MACRO    if (1) {
#define JPHP_END_MACRO      } else (void)(0)
#define JPHP_STDARGS        JNIEnv *e, jobject o

#define UNREFERENCED(P)      (P) = (P)
#define UNREFERENCED_STDARGS e = e; o = o

#define JPHP_LOAD_CLASS(E, C, N, R)                 \
    JPHP_BEGIN_MACRO                                \
        jclass _##C = (*(E))->FindClass((E), N);    \
        if (_##C == NULL) {                         \
            (*(E))->ExceptionClear((E));            \
            jniThrowIOException(E, "Can't find SAPI class"); \
            return R;                               \
        }                                           \
        C = (*(E))->NewGlobalRef((E), _##C);        \
        (*(E))->DeleteLocalRef((E), _##C);          \
    JPHP_END_MACRO

#define JPHP_UNLOAD_CLASS(E, C)                     \
        (*(E))->DeleteGlobalRef((E), (C))

#define JGETSTRING(T, S, P)                             \
    JPHP_BEGIN_MACRO                                    \
        if (S) {                                        \
            const char *c##S;                           \
            c##S = (*e)->GetStringUTFChars(e, S, NULL); \
            (T) = spstrdup((P), c##S);                  \
            (*e)->ReleaseStringUTFChars(e, S, c##S);    \
        } else (T) = NULL;                              \
    JPHP_END_MACRO


#define JPHP_ALLOC_CSTRING(V)     \
    const char *c##V = V ? (const char *)((*e)->GetStringUTFChars(e, V, 0)) : NULL

#define J2S(V)  c##V
#define J2C(V)  (char *)c##V

#define JPHP_FREE_CSTRING(V)      \
    if (c##V) (*e)->ReleaseStringUTFChars(e, V, c##V)

#define STR_TO_JSTRING(V)   (*e)->NewStringUTF((e), (V))

/* We allocate those on our pool so we have prevent php cleaning them in its pool (efree()) */
#define CLEAN_REQUEST_INFO(V) \
    SG(V).request_method = NULL; \
    SG(V).query_string = NULL; \
    SG(V).content_type = NULL; \
    SG(V).auth_user = NULL; \
    SG(V).request_uri = NULL; \
    SG(V).path_translated = NULL; \
    SG(V).cookie_data = NULL

static jclass jni_SAPI_class = NULL;

static struct {
    jmethodID   m;
    const char *n;
    const char *s;
} jni_SAPI_methods[] = {
    { NULL,
        "write",
        "(Ljavax/servlet/http/HttpServletResponse;[BI)I"
    },
    { NULL,
        "read",
        "(Ljavax/servlet/http/HttpServletRequest;[BI)I"
    },
    {
        NULL,
        "log",
        "(Lorg/apache/catalina/servlets/php/Handler;Ljava/lang/String;)V"
    },
    {
        NULL,
        "flush",
        "(Ljavax/servlet/http/HttpServletResponse;)I"
    },
    {
        NULL,
        "header",
        "(ZLjavax/servlet/http/HttpServletResponse;Ljava/lang/String;Ljava/lang/String;)V"
    },
    {
        NULL,
        "status",
        "(Ljavax/servlet/http/HttpServletResponse;I)V"
    },
    {
        NULL,
        "env",
        "(Lorg/apache/catalina/servlets/php/ScriptEnvironment;)[Ljava/lang/String;"
    },
    {
        NULL,
        "cookies",
        "(Lorg/apache/catalina/servlets/php/ScriptEnvironment;)Ljava/lang/String;"
    },
    {
        NULL,
        NULL,
        NULL
    }
};


/*
 * Convenience function to help throw an java.io.IOException.
 */
static void jniThrowIOException(JNIEnv *env, const char *msg)
{
    jclass javaExceptionClass;

    javaExceptionClass = (*env)->FindClass(env, "java/io/IOException");
    if (javaExceptionClass == NULL) {
        fprintf(stderr, "Cannot find java/io/IOException class\n");
        return;
    }
    (*env)->ThrowNew(env, javaExceptionClass, msg);
    (*env)->DeleteLocalRef(env, javaExceptionClass);
}

/*
 * Convenience function to help throw an javax.servlet.ServletException.
 */
static void jniThrowServletException(JNIEnv *env, const char *msg)
{
    jclass javaExceptionClass;

    javaExceptionClass = (*env)->FindClass(env, "javax/servlet/ServletException");
    if (javaExceptionClass == NULL) {
        fprintf(stderr, "Cannot find javax/servlet/ServletException class\n");
        return;
    }
    (*env)->ThrowNew(env, javaExceptionClass, msg);
    (*env)->DeleteLocalRef(env, javaExceptionClass);
}

#define DEFAULT_POOL_SIZE 128

typedef struct servlet_pool {
    void  **nodes;
    size_t size;
    size_t pos;
} servlet_pool;

typedef struct {
    JNIEnv          *e;
    jobject         handler;
    jobject         env;
    jobject         req;
    jobject         res;
    jbyteArray      buf;
    uint            buf_size;
    int             in_shutdown;
    servlet_pool    *p;
} servlet_request;

static void spdestroy(servlet_pool *p)
{
    unsigned int i;
    for (i = 0; i < p->pos; i++) {
        if (p->nodes[i])
            free(p->nodes[i]);
    }
    if (p->nodes)
        free(p->nodes);
    free(p);
}

static servlet_pool *spnew()
{
    servlet_pool *p;

    p = (servlet_pool *)malloc(sizeof(servlet_pool));
    if (p) {
        p->size = DEFAULT_POOL_SIZE;
        p->pos  = 0;
        p->nodes = (void **)malloc(p->size * sizeof(void *));
        if (!p->nodes) {
            free(p);
            return NULL;
        }
    }
    return p;
}

static void *spalloc(servlet_pool *p, size_t size)
{
    void *rc;

    if (p->size == p->pos) {
        size_t nsize = p->size * 2 + DEFAULT_POOL_SIZE;
        void **nnodes = (void **)malloc(nsize * sizeof(void *));
        if (nnodes) {
            if (p->nodes) {
                /* Copy old dynamic slots */
                memcpy(nnodes, p->nodes, p->size * sizeof(void *));
                free(p->nodes);
            }
            p->nodes = nnodes;
            p->size  = nsize;
        }
        else {
            return NULL;
        }
    }

    rc = p->nodes[p->pos] = calloc(1, size);
    if (p->nodes[p->pos]) {
        p->pos++;
    }
    return rc;
}

static char *spstrdup(servlet_pool *p, const char *s)
{
    char *rc;

    if (p->size == p->pos) {
        size_t nsize = p->size * 2 + DEFAULT_POOL_SIZE;
        void **nnodes = (void **)malloc(nsize * sizeof(void *));
        if (nnodes) {
            if (p->nodes) {
                /* Copy old dynamic slots */
                memcpy(nnodes, p->nodes, p->size * sizeof(void *));
                free(p->nodes);
            }
            p->nodes = nnodes;
            p->size  = nsize;
        }
        else {
            return NULL;
        }
    }

    rc = p->nodes[p->pos] = strdup(s);
    if (p->nodes[p->pos]) {
        p->pos++;
    }
    return rc;
}

static void php_info_servlet(ZEND_MODULE_INFO_FUNC_ARGS)
{
    servlet_request *r = SG(server_context);
    JNIEnv *e;

    /* If we haven't registered a server_context yet,
     * then don't bother obtaining info. */
    if (!r) {
        return;
    }
    e = r->e;

    php_info_print_table_start();
    php_info_print_table_header(2, "Server Variable", "Value");
    /* TODO: Obtain info. Not needed actually.
     */
    php_info_print_table_end();
}


static zend_module_entry php_servlet_module = {
    STANDARD_MODULE_HEADER,
    "php5servlet",
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    php_info_servlet,
    NULL,
    STANDARD_MODULE_PROPERTIES
};


static int sapi_servlet_ub_write(const char *str, uint str_length TSRMLS_DC)
{
    servlet_request *r = SG(server_context);
    JNIEnv *e;
    uint wr = 0;

    /* If we haven't registered a server_context yet,
     * then don't bother writting. */
    if (!r) {
        return str_length;
    }
    e = r->e;
    while (wr < str_length) {
        jint rv;
        uint len = str_length - wr;
        if (len > r->buf_size)
            len = r->buf_size;
        (*e)->SetByteArrayRegion(e, r->buf, 0, len, (jbyte *)(str + wr));
        rv = (*e)->CallStaticIntMethod(e, jni_SAPI_class,
                                       jni_SAPI_methods[0].m,
                                       r->res, r->buf, len);
        if (rv > 0)
            wr += rv;
        else {
            break;
        }
    }
    return wr;
}


static int sapi_servlet_header_handler(sapi_header_struct *sapi_header,
                                       sapi_headers_struct *sapi_headers TSRMLS_DC)
{
    servlet_request *r = SG(server_context);
    JNIEnv *e;
    char *val;

    /* If we haven't registered a server_context,
     * then don't bother sending header. */
    if (!r) {
        return SAPI_HEADER_ADD;
    }
    e = r->e;
    val = strchr(sapi_header->header, ':');
    if (!val) {
        sapi_free_header(sapi_header);
        return 0;
    }
    *val = '\0';
    do {
        val++;
    } while (*val == ' ');
    (*e)->CallStaticVoidMethod(e, jni_SAPI_class,
                               jni_SAPI_methods[4].m,
                               sapi_header->replace ? JNI_TRUE : JNI_FALSE,
                               r->res,
                               STR_TO_JSTRING(sapi_header->header),
                               STR_TO_JSTRING(val));

    return SAPI_HEADER_ADD;
}



static int sapi_servlet_send_headers(sapi_headers_struct *sapi_headers TSRMLS_DC)
{
    servlet_request *r = SG(server_context);
    JNIEnv *e;

    if (!r) {
        return SAPI_HEADER_SENT_SUCCESSFULLY;
    }
    e = r->e;
    (*e)->CallStaticVoidMethod(e, jni_SAPI_class,
                               jni_SAPI_methods[5].m,
                               r->res,
                               SG(sapi_headers).http_response_code);

    return SAPI_HEADER_SENT_SUCCESSFULLY;
}


static int php_servlet_startup(sapi_module_struct *sapi_module)
{
    if (php_module_startup(sapi_module, &php_servlet_module, 1) == FAILURE) {
        return FAILURE;
    }
    else {
        return SUCCESS;
    }
}


static int sapi_servlet_read_post(char *buffer, uint count_bytes TSRMLS_DC)
{
    servlet_request *r = SG(server_context);
    JNIEnv *e;
    uint rd = 0;

    /* If there is no server_context,
     * or we are in request shutdown, then don't bother reading.
     */
    if (r == NULL || r->in_shutdown) {
        return 0;
    }
    e = r->e;
    while (rd < count_bytes) {
        jint rv;
        uint len = count_bytes - rd;
        if (len > r->buf_size)
            len = r->buf_size;
        rv = (*e)->CallStaticIntMethod(e, jni_SAPI_class,
                                       jni_SAPI_methods[1].m,
                                       r->req, r->buf, len);
        if (rv > 0) {
            (*e)->GetByteArrayRegion(e, r->buf, 0, rv,
                                     buffer + rd);
            rd += rv;
        }
        else {
            break;
        }
    }

    return rd;
}


static char *sapi_servlet_read_cookies(TSRMLS_D)
{
    servlet_request *r = SG(server_context);
    JNIEnv *e;
    jstring cookie;

    /* If we haven't registered a server_context,
     * then don't bother reading cookies. */
    if (!r) {
        return spstrdup(r->p, "");
    }
    e = r->e;
    cookie = (*e)->CallStaticObjectMethod(e, jni_SAPI_class,
                                          jni_SAPI_methods[7].m,
                                          r->env);
    if (cookie) {
        char *rv;
        JPHP_ALLOC_CSTRING(cookie);
        rv = spstrdup(r->p, J2S(cookie));
        JPHP_FREE_CSTRING(cookie);
        return rv;
    }
    return spstrdup(r->p, "");
}



static void sapi_servlet_register_variables(zval *track_vars_array TSRMLS_DC)
{
    servlet_request *r;
    JNIEnv *e;
    jobjectArray env;

    r = SG(server_context);
    /* If we haven't registered a server_context,
     * then don't bother reading headers. */
    if (!r) {
        return;
    }
    e = r->e;

    env = (*e)->CallStaticObjectMethod(e, jni_SAPI_class,
                                       jni_SAPI_methods[6].m,
                                       r->env);
    if (env) {
        jsize i;
        jsize len = (*e)->GetArrayLength(e, env);
        for (i = 0 ; i < len; i += 2) {
            jstring key = (*e)->GetObjectArrayElement(e, env, i);
            jstring val = (*e)->GetObjectArrayElement(e, env, i + 1);
            JPHP_ALLOC_CSTRING(key);
            JPHP_ALLOC_CSTRING(val);

            php_register_variable(J2C(key), J2C(val), track_vars_array TSRMLS_CC);

            JPHP_FREE_CSTRING(key);
            JPHP_FREE_CSTRING(val);
            (*e)->DeleteLocalRef(e, key);
            (*e)->DeleteLocalRef(e, val);
        }
    }
}

static void
sapi_servlet_flush(void *server_context)
{
    servlet_request *r;
    JNIEnv *e;
    TSRMLS_FETCH();

    r = server_context;
    /* If we haven't registered a server_context yet,
     * then don't bother flushing. */
    if (!server_context) {
        return;
    }
    e = r->e;
    sapi_send_headers(TSRMLS_C);

    (*e)->CallStaticVoidMethod(e, jni_SAPI_class,
                               jni_SAPI_methods[5].m,
                               r->res,
                               SG(sapi_headers).http_response_code);
    SG(headers_sent) = 1;
    if ((*e)->CallStaticIntMethod(e, jni_SAPI_class,
                                  jni_SAPI_methods[3].m,
                                  r->res) < 0) {
        php_handle_aborted_connection();
    }
}

static void sapi_servlet_log_message(char *msg)
{
    servlet_request *r;
    JNIEnv *e;
    TSRMLS_FETCH();

    r = SG(server_context);

    /* If we haven't registered a server_context,
     * then don't bother logging. */
    if (!r) {
        return;
    }
    e = r->e;
    fprintf(stderr, msg);
    /*
     * TODO: Log the message
    (*e)->CallStaticVoidMethod(e, jni_SAPI_class,
                               jni_SAPI_methods[2].m,
                               r->handler,
                               STR_TO_JSTRING(msg));
    */
}


static sapi_module_struct isapi_sapi_module = {
    "php5servlet",                  /* name */
    "PHP Servlet Module",           /* pretty name */

    php_servlet_startup,            /* startup */
    php_module_shutdown_wrapper,    /* shutdown */

    NULL,                           /* activate */
    NULL,                           /* deactivate */

    sapi_servlet_ub_write,          /* unbuffered write */
    sapi_servlet_flush,             /* flush */
    NULL,                           /* get uid */
    NULL,                           /* getenv */

    php_error,                      /* error handler */

    sapi_servlet_header_handler,    /* header handler */
    sapi_servlet_send_headers,      /* send headers handler */
    NULL,                           /* send header handler */

    sapi_servlet_read_post,         /* read POST data */
    sapi_servlet_read_cookies,      /* read Cookies */

    sapi_servlet_register_variables, /* register server variables */
    sapi_servlet_log_message,       /* Log message */
    NULL,                           /* Get request time */

    STANDARD_SAPI_MODULE_PROPERTIES
};


static void php_servlet_report_exception(char *message, int message_len TSRMLS_DC)
{
    if (!SG(headers_sent)) {

        SG(headers_sent) = 1;
    }
    sapi_servlet_ub_write(message, message_len TSRMLS_CC);
}

JPHP_IMPLEMENT_CALL(jint, Handler, php)(JPHP_STDARGS,
                                        jbyteArray buf,
                                        jobject env,
                                        jobject req,
                                        jobject res,
                                        jstring requestMethod,
                                        jstring queryString,
                                        jstring contentType,
                                        jstring authUser,
                                        jstring requestURI,
                                        jstring pathTranslated,
                                        jint contentLength,
                                        jboolean syntaxHighlight)

{
    zend_file_handle zfh;
    zend_bool stack_overflown = 0;
    int retval = FAILURE;
    servlet_request *request = NULL;
    servlet_pool *pool = NULL;
    TSRMLS_FETCH();

    zend_first_try {
        if ((pool = spnew()) == NULL) {
            zend_bailout();
            return -1;
        }
        request = spalloc(pool, sizeof(servlet_request));
        request->p = pool;
        request->e = e;
        request->handler = o;
        request->env = env;
        request->req = req;
        request->res = res;
        request->buf = buf;
        if (buf)
            request->buf_size = (uint)((*e)->GetArrayLength(e, buf));

        /* Initialize the request */
        JGETSTRING(SG(request_info).request_method, requestMethod, pool);
        JGETSTRING(SG(request_info).query_string, queryString, pool);
        JGETSTRING(SG(request_info).content_type, contentType, pool);
        JGETSTRING(SG(request_info).auth_user, authUser, pool);
        JGETSTRING(SG(request_info).request_uri, requestURI, pool);
        JGETSTRING(SG(request_info).path_translated, pathTranslated, pool);
        SG(request_info).content_length = contentLength < 0 ? 0 : contentLength;
        SG(sapi_headers).http_response_code = 200;

        SG(server_context) = request;

        if (php_request_startup(TSRMLS_C) == FAILURE) {
            jniThrowServletException(e, "Request startup failed");
            spdestroy(pool);
            return -1;

        }
        zfh.filename = SG(request_info).path_translated;
        zfh.free_filename = 0;
        zfh.type = ZEND_HANDLE_FILENAME;
        zfh.opened_path = NULL;

        /* open the script here so we can 404 if it fails */
        if (zfh.filename)
            retval = php_fopen_primary_script(&zfh TSRMLS_CC);

        if (!zfh.filename || retval == FAILURE) {
            SG(sapi_headers).http_response_code = 404;
            sapi_servlet_log_message("No input file specified.");
        }
        else {
            if (syntaxHighlight == JNI_TRUE) {
                zend_syntax_highlighter_ini syntax_highlighter_ini;
                php_get_highlight_struct(&syntax_highlighter_ini);
                highlight_file(zfh.filename, &syntax_highlighter_ini TSRMLS_CC);
            }
            else {
                php_execute_script(&zfh TSRMLS_CC);
                if (!SG(headers_sent))
                    php_header(TSRMLS_C);
            }
        }
        request->in_shutdown = 1;
        CLEAN_REQUEST_INFO(request_info);
        php_request_shutdown(NULL);
        /* Destroy the request */
        SG(server_context) = NULL;
        spdestroy(pool);
        pool = NULL;
    } zend_catch {
        zend_try {
            CLEAN_REQUEST_INFO(request_info);
            if (!request->in_shutdown) 
                php_request_shutdown(NULL);
            if (pool) {
                spdestroy(pool);
                pool = NULL;
            }
        } zend_end_try();
        return -1;
    } zend_end_try();

    return 0;
}

static int php_module_started = 0;


JPHP_IMPLEMENT_CALL(jint, Library, version)(JPHP_STDARGS, jint what)
{
    UNREFERENCED_STDARGS;
    switch (what) {
        case 1:
            return PHP_MAJOR_VERSION;
        break;
        case 2:
            return PHP_MINOR_VERSION;
        break;
        case 3:
            return PHP_RELEASE_VERSION;
        break;
    }
    return 0;
}

JPHP_IMPLEMENT_CALL(jboolean, Library, startup)(JPHP_STDARGS)
{
    UNREFERENCED(o);
    if (!php_module_started) {
        char *lf;
        int ll = TSRM_ERROR_LEVEL_ERROR;
        if ((lf = getenv("TSRM_LOG_FILE")) != NULL) {
            char *l = getenv("TSRM_LOG_LEVEL");
            if (l != NULL)
                ll = atoi(l);
            else
                ll = TSRM_ERROR_LEVEL_ERROR;
        }
        tsrm_startup(128, 1, ll, lf);
        sapi_startup(&isapi_sapi_module);
        if (isapi_sapi_module.startup) {
            isapi_sapi_module.startup(&sapi_module);
        }
        php_module_started = 1;
    }
    return JNI_TRUE;
}

JPHP_IMPLEMENT_CALL(void, Library, shutdown)(JPHP_STDARGS)
{
    UNREFERENCED_STDARGS;
    if (php_module_started) {
        php_module_started = 0;
        if (isapi_sapi_module.shutdown) {
            isapi_sapi_module.shutdown(&sapi_module);
        }
        sapi_shutdown();
        tsrm_shutdown();
    }
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved)
{
    JNIEnv *env;
    int i = 0;
    if ((*vm)->GetEnv(vm, (void **)&env, JNI_VERSION_1_4)) {
        return JNI_ERR;
    }

    /* Initialize global java.lang.String class */
    JPHP_LOAD_CLASS(env, jni_SAPI_class,
                    "org/apache/catalina/servlets/php/SAPI",
                    JNI_ERR);
    while (jni_SAPI_methods[i].n) {
        jni_SAPI_methods[i].m = (*env)->GetStaticMethodID(env, jni_SAPI_class,
                                                          jni_SAPI_methods[i].n,
                                                          jni_SAPI_methods[i].s);
        if (jni_SAPI_methods[i].m == NULL) {
            jniThrowIOException(env, "Can't find method of SAPI class");
            return JNI_ERR;
        }
        i++;
    }

    return  JNI_VERSION_1_4;
}

JNIEXPORT void JNICALL JNI_OnUnload(JavaVM *vm, void *reserved)
{
    JNIEnv *env;
    if ((*vm)->GetEnv(vm, (void **)&env, JNI_VERSION_1_4)) {
        return;
    }
    /* Unload SAPI class */
    JPHP_UNLOAD_CLASS(env, jni_SAPI_class);
}

#ifdef WIN32
JNIEXPORT BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved)
{
    switch (fdwReason) {
        case DLL_PROCESS_ATTACH:
            break;
        case DLL_THREAD_ATTACH:
            break;
        case DLL_THREAD_DETACH:
            if (php_module_started)
                ts_free_thread();
            break;
        case DLL_PROCESS_DETACH:
            if (php_module_started) {
                php_module_started = 0;
                if (isapi_sapi_module.shutdown) {
                    isapi_sapi_module.shutdown(&sapi_module);
                }
                sapi_shutdown();
                tsrm_shutdown();
            }
            break;
    }
    return TRUE;
}
#endif
