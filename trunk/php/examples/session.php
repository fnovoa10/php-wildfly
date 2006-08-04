<?php
//
// JBoss, the OpenSource J2EE webOS
//
// Distributable under LGPL license.
// See terms of license at gnu.org.
//

// Show how to use session in php.
session_start();
if (!isset($_SESSION['count'])) {
   $_SESSION['count'] = 0;
} else {
   $_SESSION['count']++;
}
  print "You have access that page " . $_SESSION['count'] . " times.<br>";
?> 
