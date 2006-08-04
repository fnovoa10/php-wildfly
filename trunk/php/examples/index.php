<?php
//
// JBoss, the OpenSource J2EE webOS
//
// Distributable under LGPL license.
// See terms of license at gnu.org.
//

// Build a list of files ending with .php
function dirPhp ($directory)
{
  $results = array();
  $handler = opendir($directory);
  while ($file = readdir($handler)) {
    if ($file != '.' && $file != '..') {
      $ext = substr(strrchr($file, '.'), 1);
      if ($ext == "php")
        $results[] = $file;
    }
  }
  closedir($handler);
  return $results;
}

// main part (build an index of the php files to allow easy testing.
$phpfile = dirPhp(".");
$count = count($phpfile);
print "For the moment " . $count . " tests are available.<br>";
for ($i = 0; $i < $count; $i++)
{
  print "<a href=\"" . $phpfile[$i] . "\">" . $phpfile[$i] . "<br />";
}
?>
