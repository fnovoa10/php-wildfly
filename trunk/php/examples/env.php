<?php
//
// JBoss, the OpenSource J2EE webOS
//
// Distributable under LGPL license.
// See terms of license at gnu.org.
//

  // Display mostly used php apache environment variables.
  session_start();
  print "<html>";
  print "<head>";
  print "<title>PHP Environment display test page</title>";
  print "</head>";
  print "<body bgcolor=white>";

  print "<h1>Sample Application PHP</h1>";
  print "This is the output of a php file that is part of ";
  print "the env test application.  It displays the ";
  print "request headers from the request we are currently ";
  print "processing.<br>";
  print $_SERVER["UNIQUE_ID"] . " " . $_SERVER["HTTPS"] . "<br>";
  print $_SERVER["UNIQUE_ID"] . "<br>";
  print $_SERVER["HTTPS"] . "<br>";
  print $_SERVER["SSL_SESSION_ID"] . "<br>";

  print "<h1>Print the _SERVER array</h1>";
  do {
    print "Key: ". key($_SERVER). " value: " . current($_SERVER) . "<br>";
  } while (each($_SERVER));

  print "<h1>Print the env data</h1>";
  do {
    print "Key: ". key($_ENV). " value: " . current($_ENV) . "<br>";
  } while (each($_ENV));

  print "<h1>Print the cookie data</h1>";
  do {
    print "Key: ". key($_COOKIE). " value: " . current($_COOKIE) . "<br>";
  } while (each($_COOKIE));

  print "<h1>Print the get(ted) data</h1>";
  do {
    print "Key: ". key($_GET). " value: " . current($_GET) . "<br>";
  } while (each($_GET));

  print "<h1>Print the post(ed) data</h1>";
  do {
    print "Key: ". key($_POST). " value: " . current($_POST) . "<br>";
  } while (each($_POST));

  print "<h1>Print the files(no idea what is that!) data</h1>";
  do {
    print "Key: ". key($_FILES). " value: " . current($_FILES) . "<br>";
  } while (each($_FILES));

  print "<h1>Print the session data</h1>";
  print "_SESSION: ". $_SESSION . "<br>";
  do {
    print "Key: ". key($_SESSION). " value: " . current($_SESSION) . "<br>";
  } while (each($_SESSION));

  // $GLOBALS no purpose ;-)

  print "</body>";
  print "</html>";

?>
