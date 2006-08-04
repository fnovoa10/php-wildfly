<?php
  $page = array(1 => 'one', 2 => 'two', 3 => 'three');
  $count = count($page);
  // for (reset($pages);$key=key($pages);next($pages))
  for ($i = 0; $i <= $count; $i++)
  {
    print $page[$i] . "<br />";
  }
  reset($page);
  print next($page) . "<br />";
  print next($page) . "<br />";

  $titi = "Tenim titis";

  product($page);

  // product($titi);

  function product ($x)
  {
    print "<hr />";
    print next($x) . "<br />";
    print next($x) . "<br />";
  } 
?>
