#/bin/bash
#
# JBoss, the OpenSource J2EE webOS
#
# Distributable under LGPL license.
# See terms of license at gnu.org.
#
# Build php and its extensions
# There are windoze binaries
#

PHPVER=5.2.1
PHPURL=http://de.php.net/distributions/php-${PHPVER}.tar.gz

XML2VER=2.6.24
XML2URL=ftp://xmlsoft.org/libxml2/libxml2-${XML2VER}.tar.gz

PSQLVER=8.1.8
PSQLURL=http://wwwmaster.postgresql.org/redir?ftp://ftp2.ch.postgresql.org/pub/postgresql/source/v${PSQLVER}/postgresql-${PSQLVER}.tar.gz

OSSLVER="0.9.8b"
OSSLURL=http://www.openssl.org/source/openssl-${OSSLVER}.tar.gz

LPNGVER="1.2.10"
LPNGURL=http://kent.dl.sourceforge.net/sourceforge/libpng/libpng-${LPNGVER}.tar.gz

JPEGVER="6b"
JPEGURL=http://www.ijg.org/files/jpegsrc.v${JPEGVER}.tar.gz

GTTXVER="0.14.5"
GTTXURL=ftp://ftp.gnu.org/gnu/gettext/gettext-${GTTXVER}.tar.gz

KRB5VER="1.4.3"
KRB5URL=http://web.mit.edu/kerberos/dist/krb5/1.4/krb5-${KRB5VER}-signed.tar

MSQLVER="4.1.20"
MSQLURL=http://dev.mysql.com/get/Downloads/MySQL-4.1/mysql-4.1.20.tar.gz/from/http://mirror.switch.ch/ftp/mirror/mysql/
#MSQLVER="5.0.22"
#MSQLURL="http://dev.mysql.com/get/Downloads/MySQL-5.0/mysql-5.0.22.tar.gz/from/http://mirror.switch.ch/ftp/mirror/mysql/"

LDAPVER=2.2.13
LDAPURL=http://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-${LDAPVER}.tgz

ICNVVER=1.9.2
ICNVURL=http://ftp.gnu.org/pub/gnu/libiconv/libiconv-${ICNVVER}.tar.gz

FTT2VER=2.1.9
FTT2URL=http://switch.dl.sourceforge.net/sourceforge/freetype/freetype-${FTT2VER}.tar.gz

LBGDVER=2.0.28
LBGDURL=http://www.boutell.com/gd/http/gd-${LBGDVER}.tar.gz

# Platfrom directory and cache
TOOLS=$HOME/`uname -s`_`uname -p`_tools
CACHE=`uname -s`_`uname -p`_cache

# default value for variables.
BUILDKRB5=true
BUILDGTTX=true
BUILDXML2=true
BUILDPSQL=true
BUILDOSSL=true
BUILDLPNG=true
BUILDJPEG=true
BUILDMSQL=false
BUILDLDAP=true
BUILDICNV=false
BUILDFTT2=false
BUILDLBGD=true
CC=gcc
COMPILER=""
ADDCONF=""
LGDCONF=""

ALLOWCRYPTO=false

#
# Fonctions
# Extract
# $1 : directory base name
# $2 : URL
# $3 : version (add to the basename to the directory name).
Extract()
{
BASE=$1
URL=$2
VER=$3
case ${URL} in
  *.tar.gz | *.tgz | *signed.tar)
    FILE=`basename $URL`
    ;;
  */from/*)
    FILE=`echo $URL | sed 's:/from/: :' | awk ' { print $1 } '`
    FILE=`basename $FILE`
    ;;
esac
if [ ! -f ${FILE} ]
then
  wget ${URL}
  if [ $? -ne 0 ]
  then
    echo "wget of ${URL} failed"
    exit 1
  fi
fi
if [ ! -d ${BASE}-${VER} ]
then
  case ${FILE} in
    *.tar.gz | *.tgz)
      gzip -dc ${FILE} | tar xvf -
      ;;
    *signed.tar)
      # MIT stuff
      tar xvf ${FILE}
      gzip -dc ${BASE}-${VER}.tar.gz | tar xvf -
      ;;
    *)
      # something else...
      echo "Unknown format $FILE"
      exit 1
      ;;
  esac
  # Check if patches available.
  if [ -f patch/${BASE}-${VER}.patch ]
  then
    patch -p0 < patch/${BASE}-${VER}.patch
  fi
fi
}

#
# configure and install
# $1 : Source base directory
# $2 : Install directory
# $3 : Additional parameters for that machines/product.
# $4 : Parameter like additional make command
#      depend : Do make depend
#      libtool : copy libtool
#      clean : remove existing installed dir.
Build()
{
BASDIR=$1
INSDIR=$2
ADDCON=$3
ADDOPE=$4
SUBDIR=$5
echo "************************* Configure in ${BASDIR} ********************"
echo "parameters: --prefix=${INSDIR} ${ADDCON}"
case "${ADDOPE}" in
  *clean*)
    echo "cleaning ${INSDIR}"
    rm -rf ${INSDIR}
    ;;
esac
if [ -z "${SUBDIR}" ]
then
  SRCDIR=${BASDIR}
else
  SRCDIR=${BASDIR}/${SUBDIR}
fi
if [ ! -d ${SRCDIR} ]
then
  echo "Can't find ${SRCDIR}"
  exit 1
fi
rm -f ${BASDIR}/${SUBDIR}/config.cache
rm -f ${BASDIR}/${SUBDIR}/config.status
(cd ${SRCDIR}
 if [ ${CC} = "cc" ]
 then
   # Sun Studio
   CC=cc CPPFLAGS="$CPPFLAGS" ./configure --prefix=${INSDIR} ${ADDCON}
 else
   ./configure --prefix=${INSDIR} ${ADDCON}
 fi
 if [ $? -ne 0 ]
 then
   echo "configure in ${SRCDIR} failed"
   exit 1
 fi
 case "${ADDOPE}" in
   *depend*)
     make depend
     if [ $? -ne 0 ]
     then
       echo "Make depend in ${SRCDIR} failed"
       exit 1
     fi
     ;;
 esac
 case "${ADDOPE}" in
   *libtool*)
   # On Solaris the libtool of old packages is broken
   # It does not build shared libraries.
   echo "Copying libtool" 
   if [ -f $TOOLS/bin/libtool ]
   then
     cp $TOOLS/bin/libtool .
   else
     # Use the system libtool on Linux
     if [ $OS == Linux ]
     then
       LIBTOOL=`which libtool`
       if [ -f $LIBTOOL ]
       then
         cp $LIBTOOL .
       else
         echo "$TOOLS/bin/libtool doesn't exist" 
         exit 1
       fi
     else
       echo "$TOOLS/bin/libtool doesn't exist" 
       exit 1
     fi
   fi
 esac
 make clean
 if [ $? -ne 0 ]
 then
   echo "Make clean in ${SRCDIR} failed"
   exit 1
 fi
 make 
 if [ $? -ne 0 ]
 then
   echo "Make in ${SRCDIR} failed"
   exit 1
 fi
 make install
 if [ $? -ne 0 ]
 then
   echo "Make install in ${SRCDIR} failed"
   exit 1
 fi
)
}

#
# Copy the file and the symlinks
# $1 : source directory
# $2 : file names (like "*.so*")
# $3 : destination
Copy()
{
(cd $1
 tar cvf - $2 ) | (cd $3
 tar xvf - )
}

#
# Allow to parameters to the build
while [ "x" != "x$1" ]
do
  case $1 in
    ALL)
      BUILDMSQL=true
      BUILDICNV=true
      BUILDFTT2=true
      BUILDPSQL=true
      BUILDJPEG=true
      BUILDMSQL=true
      ;;
    CRYPT)
      ALLOWCRYPTO=true
      ;;
    *)
      echo "$1: not (yet) supported"
  esac
  shift
done

#
# Prevent cryptop stuff
if ${ALLOWCRYPTO}
then
  echo "Be carefull with exporting the package: it contains crypto stuff"
else
  BUILDOSSL=false
  BUILDKRB5=false
fi

#
# depending on machine remove or add php extensions.
OS=`uname -s`
PR=`uname -p`

# try to find mysql
MYSQLDIR=
case ${OS} in
  SunOS)
    MSQLSY=solaris
    case `uname -r` in
      5.9)  MSQLPR=2.9 ;;
      5.10) MSQLPR=2.10 ;;
      *)    MSQLPR=${OS} ;;
    esac
    case `uname -m` in
      i86pc) MSQLHD=pc;;
      sun*) MSQLHD=sun;;
    esac
    MYSQL="mysql-standard-${MSQLVER}-${MSQLHD}-${MSQLSY}${MSQLPR}-${PR}"
    ;;
  Linux)
    MSQLSY=solaris
    MSQLHD=pc
    MSQLSY=linux-gnu
    MYSQL="mysql-standard-${MSQLVER}-${MSQLHD}-${MSQLSY}${MSQLPR}-${PR}-glibc23"
    ;;
esac

for dir in $HOME/${MYSQL} /usr/${MYSQL} /opt/${MYSQL} /opt/i86pc/${MYSQL}
do
  if [ -d $dir ]
  then
    MYSQLDIR=${dir}
  fi
done

# overwrite the result when we force the build
if ${BUILDMSQL}
then
  MYSQLDIR=${TOOLS}/MSQL
fi
if [ -z "${MYSQLDIR}" ]
then
  ADDCONF="$ADDCONF \
          --with-mysqli \
          --with-mysql \
          --with-pdo-mysql \
          "
else
  ADDCONF="$ADDCONF \
          --with-mysqli=${MYSQLDIR}/bin/mysql_config \
          --with-mysql=${MYSQLDIR} \
          --with-pdo-mysql=${MYSQLDIR} \
          "
fi

ADDCONF="$ADDCONF --with-t1lib=no"
case ${OS} in
  Linux)     
    EXTTYPE=static
    BUILDICNV=false
    ADDFLAGS="-I $JAVA_HOME/include/linux"
    LGDCONF="$LGDCONF --with-xpm"
    ;;
  SunOS)
    BUILDICNV=true
    BUILDFTT2=true
    pkginfo | grep SPROcc
    if [ $? -eq 0 ]
    then
      CC=cc
      export CC
    fi
    pkginfo | grep xpm
    if  [ $? -eq 0 ]
    then
      pkginfo | grep SUNWxwinc
      if [  $? -eq 0 ]
      then
        LGDCONF="$LGDCONF --with-xpm=/usr/local"
      else
        echo "Please install SUNWxwinc... Otherwise no xpm support"
        LGDCONF="$LGDCONF --without-xpm"
      fi
    fi
    # SUNWfreetype2 /usr/sfw
    # --with-freetype-dir=/usr/sfw (SUNWfreetype2 is 2.1.2)
    # don't use SMCmysql too old:  /usr/local/mysql
    EXTTYPE=shared
    ADDFLAGS="-I $JAVA_HOME/include/solaris"
    ;;
esac
case ${PR} in
  x86_64)
     #ADDCONF="$ADDCONF --with-pic"
     # with-libdir=lib64 causes problem with SSL (our openssl location).
     # but without it ldap libraries are not found.
     ADDCONF="$ADDCONF --with-libdir=lib64 --with-pic"
     ADDFLAGS="$ADDFLAGS -fPIC"
    if [ ${CC} = "cc" ]
    then
      COMPILER=solaris-x86-cc
    fi
    ;;
  sparc)
    if [ ${CC} = "cc" ]
    then
      # Why not solaris64-sparcv9-cc? (does someone still use 32?)
      COMPILER=solaris-sparcv9-cc
    fi
    ;;
  i?86)
    if [ ${CC} = "cc" ]
    then
      COMPILER=solaris-x86-cc
    fi
    ;;
esac

#
# build freetype2 if required.
if ${BUILDFTT2}
then
  # Remove files created by configure.
  rm -f freetype-${FTT2VER}/builds/unix/config.status
  rm -f freetype-${FTT2VER}/builds/unix/unix-def.mk
  rm -f freetype-${FTT2VER}/builds/unix/freetype-config
  rm -f freetype-${FTT2VER}/builds/unix/freetype2.pc
  # Extract and Build.
  Extract freetype ${FTT2URL} ${FTT2VER}
  Build freetype-${FTT2VER} ${TOOLS}/FTT2 "--enable-shared" "clean+libtool" ""
  ADDCONF="$ADDCONF --with-freetype-dir=$TOOLS/FTT2"
  LGDCONF="$LGDCONF --with-freetype=$TOOLS/FTT2"
else
  ADDCONF="$ADDCONF  --with-freetype-dir"
fi

#
# build iconv if required.
if ${BUILDICNV}
then
  Extract libiconv ${ICNVURL} ${ICNVVER}
  Build libiconv-${ICNVVER} ${TOOLS}/ICNV "--enable-shared" "clean" ""
  ADDCONF="$ADDCONF --with-iconv-dir=$TOOLS/ICNV"
  LGDCONF="$LGDCONF --with-libiconv-prefix=$TOOLS/ICNV"
fi

#
# build mysql if required.
# Note the trick ADDCONF is filled before.
if ${BUILDMSQL}
then
  Extract mysql ${MSQLURL} ${MSQLVER}
  Build mysql-${MSQLVER} ${TOOLS}/MSQL "--enable-shared" "clean" ""
fi

#
# build kerberos if required.
if ${BUILDKRB5}
then
  Extract krb5 ${KRB5URL} ${KRB5VER}
  Build krb5-${KRB5VER} ${TOOLS}/KRB5 "--enable-shared --with-tcl=no" "clean" "src"
  ADDCONF="$ADDCONF --with-kerberos=$TOOLS/KRB5"
else
  if ${ALLOWCRYPTO}
  then
    ADDCONF="$ADDCONF --with-kerberos"
  else
    ADDCONF="$ADDCONF --without-kerberos"
  fi
fi

#
# build gettext if required.
if ${BUILDGTTX}
then
  Extract gettext ${GTTXURL} ${GTTXVER}
  Build gettext-${GTTXVER} ${TOOLS}/GTTX "--enable-shared" "clean" ""
  ADDCONF="$ADDCONF --with-gettext=$TOOLS/GTTX"
else
  ADDCONF="$ADDCONF --with-gettext"
fi

#
# build lib jpeg if required
if ${BUILDJPEG}
then
  # Directory are not created by jpeg installation...
  rm -rf ${TOOLS}/JPEG
  mkdir -p ${TOOLS}/JPEG/include
  mkdir -p ${TOOLS}/JPEG/lib
  mkdir -p ${TOOLS}/JPEG/bin
  mkdir -p ${TOOLS}/JPEG/man/man1
  Extract jpeg ${JPEGURL} ${JPEGVER}
  Build jpeg-${JPEGVER} ${TOOLS}/JPEG "--enable-shared" "libtool" ""
  ADDCONF="$ADDCONF --with-jpeg-dir=$TOOLS/JPEG"
  LGDCONF="$LGDCONF --with-jpeg=$TOOLS/JPEG"
else
  ADDCONF="$ADDCONF --with-jpeg-dir"
fi

#
# build lib png if required
if ${BUILDLPNG}
then
  Extract libpng ${LPNGURL} ${LPNGVER}
  Build libpng-${LPNGVER} ${TOOLS}/LPNG "" "clean"  ""
  ADDCONF="$ADDCONF --with-png-dir=$TOOLS/LPNG"
  LGDCONF="$LGDCONF --with-png=$TOOLS/LPNG"
  # libgd makes _very_ strange things with png.
  LIBPNG_CONFIG=${TOOLS}/LPNG/bin/libpng-config
  LIBPNG12_CONFIG=${TOOLS}/LPNG/bin/libpng12-config
  CPPFLAGS="$CPPFLAGS -I${TOOLS}/LPNG/include/libpng12"
  PATH=${TOOLS}/LPNG/bin:$PATH
  export PATH
  export LIBPNG_CONFIG
  export LIBPNG12_CONFIG
  export CPPFLAGS
else
  ADDCONF="$ADDCONF --with-png-dir"
fi

#
# build libgd if required
if ${BUILDLBGD}
then
  Extract gd ${LBGDURL} ${LBGDVER}
  Build gd-${LBGDVER} ${TOOLS}/LBGD "--without-xpm $LGDCONF"  "clean" ""
  ADDCONF="$ADDCONF --with-gd=$TOOLS/LBGD \
          --enable-gd-native-ttf \
          "
else
  ADDCONF="$ADDCONF --with-gd \
          --enable-gd-native-ttf \
          "
fi

#
# build libxml2 if required
if ${BUILDXML2}
then
  Extract libxml2 ${XML2URL} ${XML2VER}
  Build libxml2-${XML2VER} ${TOOLS}/LIBXML2 "" "clean"  ""
  ADDCONF="$ADDCONF --with-libxml-dir=$TOOLS/LIBXML2"
else
  ADDCONF="$ADDCONF --with-libxml-dir"
fi

#
# build openssl if required
if ${BUILDOSSL}
then
  Extract openssl ${OSSLURL} ${OSSLVER}
  # Copied from buildworld.sh
  # Do we need --openssldir=
  (cd openssl-${OSSLVER}
   if [ ${CC} = "cc" ]
   then
     ./Configure --prefix=${TOOLS}/SSL threads no-zlib no-zlib-dynamic no-gmp no-krb5 no-rc5 no-mdc2 no-idea no-ec shared $COMPILER
   else
     ./config --prefix=${TOOLS}/SSL threads no-zlib no-zlib-dynamic no-gmp no-krb5 no-rc5 no-mdc2 no-idea no-ec shared
   fi
   make clean
   make depend
   make install
   case ${PR} in
        x86_64)
          ln -s ${TOOLS}/SSL/lib ${TOOLS}/SSL/lib64
          ;;
   esac
  )
  ADDCONF="$ADDCONF --with-openssl=$TOOLS/SSL --with-openssl-dir=$TOOLS/SSL"
else
  if ${ALLOWCRYPTO}
  then
    ADDCONF="$ADDCONF --with-openssl"
  else
    ADDCONF="$ADDCONF --without-openssl"
  fi
fi

#
# build openldap if required
if ${BUILDLDAP}
then
  Extract openldap ${LDAPURL} ${LDAPVER}
  if ${BUILDOSSL}
  then
    CPPFLAGS=-I$TOOLS/SSL/include
    export CPPFLAGS
    LDFLAGS=-L$TOOLS/SSL/lib
    export LDFLAGS
    Build openldap-${LDAPVER} ${TOOLS}/LDAP "--with-threads --disable-slapd --with-tls=openssl" "depend+clean" ""
  else
    if ${ALLOWCRYPTO}
    then
      Build openldap-${LDAPVER} ${TOOLS}/LDAP "--with-threads --disable-slapd --with-tls"  "depend+clean" ""
    else
      Build openldap-${LDAPVER} ${TOOLS}/LDAP "--with-threads --disable-slapd --without-tls --with-kerberos=no"  "depend+clean" ""
    fi
  fi
  ADDCONF="$ADDCONF --with-ldap=$TOOLS/LDAP"
else
  ADDCONF="$ADDCONF --with-ldap"
fi

#
# build postgres if required
# postgres needs openssl
if ${BUILDPSQL}
then
  Extract postgresql ${PSQLURL} ${PSQLVER}
  if ${BUILDOSSL}
  then
    Build postgresql-${PSQLVER} ${TOOLS}/POSTGRESQL "--without-readline LDFLAGS=-L${TOOLS}/SSL/lib"  "clean"  ""
  else
    Build postgresql-${PSQLVER} ${TOOLS}/POSTGRESQL --without-readline  "clean"  ""
  fi
  ADDCONF="$ADDCONF --with-pgsql=$TOOLS/POSTGRESQL --with-pdo-pgsql=$TOOLS/POSTGRESQL/bin"
else
  ADDCONF="$ADDCONF --with-pgsql --with-pdo-pgsql"
fi

#
# get and extract php
if [ ! -f php-${PHPVER}.tar.gz ]
then
  wget $PHPURL
fi
if [ ! -d php-${PHPVER} ]
then
  gzip -dc php-${PHPVER}.tar.gz | tar xvf -
fi
echo "Adding to default configuration:: ${ADDCONF}"

# remove the cache that save problems but use more time when building.
rm -f php-${PHPVER}/$CACHE

# add environment variables
if ${BUILDLBGD} && ${BUILDICNV}
then
  LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$TOOLS/ICNV/lib
  export LD_LIBRARY_PATH
  LIBS="-L$TOOLS/ICNV/lib -liconv"
  export LIBS
fi
if ${BUILDLBGD}
then
  GD_LIB="$TOOLS/LBGD/lib"
  export GD_LIB
fi
if ${BUILDLDAP}
then
  EXTRA_LDFLAGS=-L$TOOLS/LDAP/lib
  EXTRA_LDFLAGS_PROGRAM=-L$TOOLS/LDAP/lib
  export EXTRA_LDFLAGS
  export EXTRA_LDFLAGS_PROGRAM
fi

#
# Add links for some platforms
case ${PR} in
  x86_64)
    for dir in `ls ${TOOLS}`
    do
      if [ -d ${TOOLS}/${dir}/lib ]
      then
        (cd ${TOOLS}/${dir}
         ln -fs lib lib64
        )
      fi
    done
    ;;
esac

# configure php
if ! ${ALLOWCRYPTO}
then
  ADDCONF="$ADDCONF --without-iconv --without-kerberos --without-ldap-sasl --without-curl --without-bz2"
fi
if [ ${CC} = "cc" ]
then
   # Sun Studio
   CC=cc
   export CC
   #CPPFLAGS="-I/opt/SUNWspro/prod/include/CC/Cstd/rw -I/opt/SUNWspro/prod/include/CC/Cstd -DHUGE_VAL=__builtin_huge_val"
   #export CPPFLAGS
fi
(cd php-${PHPVER}
 ./configure --prefix=$TOOLS/PHP \
  --cache-file=$CACHE \
  --with-tsrm-pthreads --enable-shared \
  --enable-embed=shared \
  --enable-maintainer-zts \
  \
  --with-kerberos \
  --with-imap-ssl \
  --with-zlib-dir \
  --with-ttf \
  --with-bz2 \
  --enable-bcmath \
  --enable-calendar \
  --enable-dbase \
  --enable-dba \
  --enable-exif \
  --enable-filepro \
  --enable-ftp \
  --with-gettext \
  --enable-mbstring \
  --enable-shmop \
  --enable-soap \
  --enable-sockets \
  --enable-sysvmsg \
  --enable-sysvsem \
  --enable-sysvshm \
  --enable-wddx \
  --with-xmlrpc \
  \
  --without-pear \
  --with-ncurses=no \
  --with-fbsql=no \
  --with-fdftk=no \
  --with-gmp=no \
  --with-hwapi=no \
  --with-informix=no \
  --with-interbase=no \
  --with-ming=no \
  --with-mssql=no \
  --with-oci8=no \
  --with-pdo-oci=no \
  --with-pdo-dblib=no \
  --with-pdo-firebird=no \
  --with-pdo-odbc=no \
  --with-libedit=no \
  --disable-reflection \
  --with-snmp=no \
  --disable-spl \
  --with-sybase=no \
  --with-sybase-ct=no \
  --with-recode=no \
  --with-mcrypt=no \
  --with-mhash=no \
  \
  --with-msql=no \
  \
  ${ADDCONF}
)
if [ $? -ne 0 ]
then
  echo "Configure failed"
  exit 1
fi

#
# Clean up the possible previous build
rm -rf $TOOLS/PHP
(cd php-${PHPVER}
make clean
)
if [ $? -ne 0 ]
then
  echo "Make clean failed"
  exit 1
fi

# hack... Something try to use libldap.la for /usr/local/lib
if ${BUILDLDAP}
then
  cp $TOOLS/LDAP/lib/*.la php-${PHPVER}/
  chmod -w php-${PHPVER}/*.la
fi


(cd php-${PHPVER}
make
)
if [ $? -ne 0 ]
then
  echo "Make failed"
  exit 1
fi

(cd php-${PHPVER}
make install
)
if [ $? -ne 0 ]
then
  echo "Make install failed"
  exit 1
fi
#rm php-${PHPVER}.tar.gz 

# Now build the native part of the php5servlet
#-DZTS is the php Thread Safe Resource Manager
#-DPTHREADS to use pthreads.
#

if [ ${CC} = "cc" ]
then
   # Sun Studio
   ADDFLAGS="${ADDFLAGS} -I/opt/SUNWspro/prod/include/CC/Cstd/rw -I/opt/SUNWspro/prod/include/CC/Cstd -DHUGE_VAL=__builtin_huge_val"
fi
(cd php5servlet
 $CC -c $ADDFLAGS \
        -I $JAVA_HOME/include \
	-I $TOOLS/PHP/include/php/main \
        -I $TOOLS/PHP/include/php/Zend \
        -I $TOOLS/PHP/include/php/TSRM \
        -I $TOOLS/PHP/include/php \
        -DZTS -DPTHREADS \
        php5servlet.c
 ld -G -o libphp5servlet.so php5servlet.o -L $TOOLS/PHP/lib -lphp5
)
echo "\
$CC -c $ADDFLAGS \
       -I $JAVA_HOME/include \
       -I $TOOLS/PHP/include/php/main \
       -I $TOOLS/PHP/include/php/Zend \
       -I $TOOLS/PHP/include/php/TSRM \
       -I $TOOLS/PHP/include/php \
       -DZTS -DPTHREADS \
       php5servlet.c
ld -G -o libphp5servlet.so php5servlet.o -L $TOOLS/PHP/lib -lphp5
" > php5servlet/Make.sh
if [ -f php5servlet/libphp5servlet.so ]
then
  cp php5servlet/libphp5servlet.so $TOOLS/PHP/lib
else
  echo "libphp5servlet.so wasn't build, aborting..."
  exit 1
fi

#
# At that point everything is build.
# Copy the libraries to php/lib
if ${BUILDKRB5}
then
  Copy $TOOLS/KRB5/lib "lib*.so*" $TOOLS/PHP/lib
fi
if ${BUILDGTTX}
then
  Copy $TOOLS/GTTX/lib "lib*.so*" $TOOLS/PHP/lib
fi
if ${BUILDXML2}
then
  Copy $TOOLS/LIBXML2/lib "libxml2.so*" $TOOLS/PHP/lib
fi
if ${BUILDPSQL}
then
  Copy $TOOLS/POSTGRESQL/lib "libpq.so*" $TOOLS/PHP/lib
fi
if ${BUILDOSSL}
then
  Copy $TOOLS/SSL/lib "libcrypto.so*" $TOOLS/PHP/lib
  Copy $TOOLS/SSL/lib "libssl.so*" $TOOLS/PHP/lib
fi
if ${BUILDLPNG}
then
  Copy $TOOLS/LPNG/lib "libpng12.so*" $TOOLS/PHP/lib
fi
if ${BUILDJPEG}
then
  Copy $TOOLS/JPEG/lib "libjpeg.so*" $TOOLS/PHP/lib
fi
if ${BUILDMSQL}
then
  Copy $TOOLS/MSQL/lib "lib*.so*" $TOOLS/PHP/lib
fi
if ${BUILDLDAP}
then
  Copy $TOOLS/LDAP/lib "lib*.so*" $TOOLS/PHP/lib
fi
if ${BUILDICNV}
then
  Copy $TOOLS/ICNV/lib "lib*.so*" $TOOLS/PHP/lib
fi
if ${BUILDFTT2}
then
  Copy $TOOLS/FTT2/lib "lib*.so*" $TOOLS/PHP/lib
fi
if ${BUILDLBGD}
then
  Copy $TOOLS/LBGD/lib "lib*.so*" $TOOLS/PHP/lib
fi

#
# Build the war file with the demo
ant build-demo
mkdir -p $TOOLS/server/default/deploy/jbossweb.sar
cp -p php-examples.war $TOOLS/server/default/deploy/jbossweb.sar

#
# Build a tarball with the all stuff
(cd  $TOOLS/
 rm -f php5servlet.tar.gz
 rm -f php5servlet.tar
 tar cvf php5servlet.tar PHP/lib server/default/deploy/jbossweb.sar/php-examples.war
 gzip -9 php5servlet.tar
)

echo "Done: $TOOLS/php5servlet.tar.gz"
