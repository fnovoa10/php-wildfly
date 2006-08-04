<?php
//
// JBoss, the OpenSource J2EE webOS
//
// Distributable under LGPL license.
// See terms of license at gnu.org.
//

// A small example to test libxml2 support.
$dom = new domDocument;
$dom->loadXML('<books><book><title>blah</title></book></books>');
if (!$dom) {
     echo 'Error while parsing the document';
     exit;
}

$s = simplexml_import_dom($dom);

echo "If all is OK you should read the title of the book \"bla\": ";
echo $s->book[0]->title;
?>
