<?php
//
// JBoss, the OpenSource J2EE webOS
//
// Distributable under LGPL license.
// See terms of license at gnu.org.
//

// borrowed to martin kraemer (martin@apache.org)
// improved by jean-frederic clere (jfclere@apache.org)

  // The fonts are needed to have the nice letters.
  $fontdir = "webapps/php-examples/";

  // Try to find the font in diffent locations.
  //    $font ="shlyalln.ttf";
  $p = getcwd();
  $font = $p."/".$fontdir."dauphinn.ttf";
  if (!file_exists($font)) {
    $font =$p."/dauphinn.ttf";  
    if (!file_exists($font)) {
      die("Can't find $font");
    }
  }

  if (!isset($height))
    $height=60;

  if ( ! ($host = gethostbyaddr($_SERVER["REMOTE_ADDR"])))
    $host = $_SERVER["REMOTE_ADDR"];

  if (!isset($text))
    $text = "Hello ".$host.", nice to see you";

  if(1) {
  $imsize = ImageTTFBBox($height, 0, $font, $text);
  $im = imagecreate(abs($imsize[4]-$imsize[0])+4, abs($imsize[5]-$imsize[1])+4);
  $white = ImageColorAllocate($im, 255,255,255);
  $black = ImageColorAllocate($im, 0,0,0);
  $blue  = ImageColorAllocate($im, 0,0,255);

  ImageTTFText($im, $height,0, -$imsize[6],-$imsize[5], $black, $font, $text);

  if(function_exists("imagePng")) {
    Header("Content-type: image/png");
    ImagePng($im);
  }
  elseif(function_exists("imageJpeg")) {
    Header("Content-type: image/jpeg");
    ImageJpeg($im,"",0.5);
  }
  else
    die("No image support in this PHP server");
  ImageDestroy($im);
  } else {
  $im = imagecreate(800, $height*1.5);
  $white = ImageColorAllocate($im, 255,255,255);
  $black = ImageColorAllocate($im, 0,0,0);

  ImageTTFText($im, $height-10, 0, 10, $height-5, $black, $font, $text);

  $debug && Header("Expires: 0");
  $debug && Header("Cache-Control: no-cache");
  $debug && Header("Pragma: no-cache");

  if(function_exists("imagegif")) {
    Header("Content-type: image/gif");
    ImageGif($im);
  }
  elseif(function_exists("imageJpeg")) {
    Header("Content-type: image/jpeg");
    ImageJpeg($im,"",0.5);
  }
  elseif(function_exists("imagePng")) {
    Header("Content-type: image/png");
    ImagePng($im);
  }
  else
    die("No image support in this PHP server");
  ImageDestroy($im);
  }
?>

