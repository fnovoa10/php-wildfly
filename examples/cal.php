<?
//
// JBoss, the OpenSource J2EE webOS
//
// Distributable under LGPL license.
// See terms of license at gnu.org.
//

// borrowed to martin kraemer (martin@apache.org)
// improved by jean-frederic clere (jfclere@apache.org)

// Size and border.
$width = 640;
$height = 480;
$border = 36;

$ring_x = 20; /* ring-breite links & rechts von center line */
$ring_y = 4;  /* ring-hoehe  +/- y-line */
$ring_off_1 = 60; /* 1. ringabstand +/- y-richtung von mittelpunkt */
$ring_off_2 = 130;/* 2. ringabstand +/- y-richtung von mittelpunkt */
$line_off = 10; /* abstand der Tages-Linie vom Papierrand */

$hh_min = 8;	// from 08:00h
$hh_max = 18;	// to 18:00h

$WkDay = array("So", "Mo", "Di", "Mi", "Do", "Fr", "Sa", "So");
$Months = array("Jan", "Feb", "Mdr", "Apr", "Mai", "Jun",
                "Jul", "Aug", "Sep",      "Okt", "Nov", "Dez");
$Months_Full = array(
                1=>"Januar", "Februar", "Mdrz", "April",   "Mai",      "Juni",
                   "Juli",   "August",  "September", "Oktober", "November", "Dezember");

class point_t {
   var $x,$y;
   // cfunction set($x,$y) {
   function set($x,$y) {
     $this->x = $x;
     $this->y = $y;

   }
   function as_string() {
     return '(' . $this->x . ',' . $this->y . ')';
   }
};

class rect_t {
  var $pos, $size;

  function set($pos, $size) {
    $this->pos = $pos;
    $this->size = $size;
  }

  function set4($pos_x, $pos_y, $size_x, $size_y) {
    $this->pos = point($pos_x, $pos_y);
    $this->size = size($size_x, $size_y);
  }
  function draw($im, $color, $border) {
    ImageFilledRectangle($im, $this->pos->x,           $this->pos->y,
                         $this->pos->x+$this->size->x, $this->pos->y+$this->size->y,
			 $color);
    if ($border != $color)
        ImageRectangle  ($im, $this->pos->x,           $this->pos->y,
                         $this->pos->x+$this->size->x, $this->pos->y+$this->size->y,
			 $border);
  }

  function is_within($x, $y)
  {
    return ($x >= $this->pos->x && $x < $this->pos->x+$this->size->x
         && $y >= $this->pos->y && $y < $this->pos->y+$this->size->y);
  }
};


class gifimage_t {
  var $im, $size, $center;
  var $width, $height; /* total canvas size */
  var $links, $rechts; /* min. and max. x value of paper */
  var $oben,  $unten;  /* min. and max. y value of paper */

  function gifimage($size, $x_border, $y_border) {
    $this->size = $size;
    $this->center = point($size->x/2, $size->y/2);

    $this->width = $size->x;
    $this->height = $size->y;

    $this->links  = $x_border;
    $this->rechts = $this->width  - $x_border;
    $this->oben   = $y_border;
    $this->unten  = $this->height - $y_border;

    /* Create Image */
    $this->im = ImageCreate($size->x, $size->y);
  }
  function draw_line($x0,$y0,$x1,$y1,$color) {
    ImageLine($this->im, $x0, $y0, $x1, $y1, $color);
  }
  function draw_rect($lu_x,$lu_y,$ro_x,$ro_y,$color,$border) {
    ImageFilledRectangle($this->im, $lu_x, $lu_y, $ro_x, $ro_y, $color);
    if ($border != $color)
        ImageRectangle($this->im, $lu_x, $lu_y, $ro_x, $ro_y, $border);
  }
  function draw_circle($cx, $cy, $radius, $color, $border) {
    ImageArc($this->im, $cx, $cy, 2*$radius, 2*$radius,   0, 180, $border);
    ImageArc($this->im, $cx, $cy, 2*$radius, 2*$radius, 180, 360, $border);
    ImageFillToBorder($this->im, $cx, $cy, $border, $color);
  }
  function draw_rounded_rect($l,$o, $r,$u, $radius, $color) {
    ImageArc($this->im, $l+$radius, $o+$radius, 2*$radius, 2*$radius,   0, 180, $color);
    ImageArc($this->im, $l+$radius, $o+$radius, 2*$radius, 2*$radius, 180, 360, $color);
    ImageFillToBorder($this->im, $l+$radius, $o+$radius, $color, $color);
    ImageArc($this->im, $l+$radius, $u-$radius, 2*$radius, 2*$radius,   0, 180, $color);
    ImageArc($this->im, $l+$radius, $u-$radius, 2*$radius, 2*$radius, 180, 360, $color);
    ImageFillToBorder($this->im, $l+$radius, $u-$radius, $color, $color);
    ImageArc($this->im, $r-$radius, $u-$radius, 2*$radius, 2*$radius,   0, 180, $color);
    ImageArc($this->im, $r-$radius, $u-$radius, 2*$radius, 2*$radius, 180, 360, $color);
    ImageFillToBorder($this->im, $r-$radius, $u-$radius, $color, $color);
    ImageArc($this->im, $r-$radius, $o+$radius, 2*$radius, 2*$radius,   0, 180, $color);
    ImageArc($this->im, $r-$radius, $o+$radius, 2*$radius, 2*$radius, 180, 360, $color);
    ImageFillToBorder($this->im, $r-$radius, $o+$radius, $color, $color);
    /* Note that the 1st coord *MUST* be smaller in value than the 2nd */
    ImageFilledRectangle($this->im, $l, $o+$radius, $r, $u-$radius, $color);
    ImageFilledRectangle($this->im, $l+$radius, $o, $r-$radius, $u, $color);
  }

  function draw_planner_image() {
    global $ring_x, $ring_y, $ring_off_1, $ring_off_2;
    global $white, $grey, $btgrey, $dkgrey, $black, $green, $red, $blue;

/* Buchruecken malen */
    $this->draw_rounded_rect(0, 0, $this->width, $this->height, 10, $dkgrey);

/* Weisses Papier */
    $this->draw_rect($this->links, $this->oben, $this->rechts, $this->unten, $white, $black);

/* Trennlinie links/rechts */
    $this->draw_line($this->center->x, 0, $this->center->x, $this->height, $black);

    $this->draw_planner_rings();
  }

  function draw_planner_rings() {
    global $ring_x, $ring_y, $ring_off_1, $ring_off_2;
    global $white, $grey, $btgrey, $dkgrey, $black;

/* 4 Ringe zeichnen */
    $this->draw_circle($this->center->x - $ring_x, $this->center->y - $ring_off_2, 2*$ring_y, $dkgrey, $black);
    $this->draw_circle($this->center->x + $ring_x, $this->center->y - $ring_off_2, 2*$ring_y, $dkgrey, $black);
    $this->draw_rect($this->center->x - $ring_x, $this->center->y - $ring_off_2 - $ring_y, $this->center->x + $ring_x, $this->center->y - $ring_off_2 + $ring_y, $grey, $black);

    $this->draw_circle($this->center->x - $ring_x, $this->center->y - $ring_off_1, 2*$ring_y, $dkgrey, $black);
    $this->draw_circle($this->center->x + $ring_x, $this->center->y - $ring_off_1, 2*$ring_y, $dkgrey, $black);
    $this->draw_rect($this->center->x - $ring_x, $this->center->y - $ring_off_1 - $ring_y, $this->center->x + $ring_x, $this->center->y - $ring_off_1 + $ring_y, $grey, $black);

    $this->draw_circle($this->center->x - $ring_x, $this->center->y + $ring_off_1, 2*$ring_y, $dkgrey, $black);
    $this->draw_circle($this->center->x + $ring_x, $this->center->y + $ring_off_1, 2*$ring_y, $dkgrey, $black);
    $this->draw_rect($this->center->x - $ring_x, $this->center->y + $ring_off_1 - $ring_y, $this->center->x + $ring_x, $this->center->y + $ring_off_1 + $ring_y, $grey, $black);

    $this->draw_circle($this->center->x - $ring_x, $this->center->y + $ring_off_2, 2*$ring_y, $dkgrey, $black);
    $this->draw_circle($this->center->x + $ring_x, $this->center->y + $ring_off_2, 2*$ring_y, $dkgrey, $black);
    $this->draw_rect($this->center->x - $ring_x, $this->center->y + $ring_off_2 - $ring_y, $this->center->x + $ring_x, $this->center->y + $ring_off_2 + $ring_y, $grey, $black);
  }

  function weekday_rect ($day)
  {
    global $line_off;
    $dy = ($this->unten - $this->oben) / 13;
    switch($day)
    {
      case 1: /* mon */
        return rect($this->links+$line_off, $this->oben+$dy, ($this->rechts - $this->links)/2 - 2*$line_off, 4*$dy);
      case 2: /* tue */
        return rect($this->links+$line_off, $this->oben+5*$dy, ($this->rechts - $this->links)/2 - 2*$line_off, 4*$dy);
      case 3: /* wed */
        return rect($this->links+$line_off, $this->oben+9*$dy, ($this->rechts - $this->links)/2 - 2*$line_off, 4*$dy);
      case 4: /* thu */
        return rect($this->center->x+$line_off, $this->oben+$dy, ($this->rechts - $this->links)/2 - 2*$line_off, 4*$dy);
      case 5: /* fri */
        return rect($this->center->x+$line_off, $this->oben+5*$dy, ($this->rechts - $this->links)/2 - 2*$line_off, 4*$dy);
      case 6: /* sat */
        return rect($this->center->x+$line_off, $this->oben+9*$dy, ($this->rechts - $this->links)/2 - 2*$line_off, 2*$dy);
      case 7: /* sun */
      case 0: /* sun */
        return rect($this->center->x+$line_off, $this->oben+11*$dy, ($this->rechts - $this->links)/2 - 2*$line_off, 2*$dy);
    }
  }

  function draw_week() {
    global $red, $black, $dkgrey;
    global $line_off;

    for ($i=1; $i <= 7; ++$i)
    {
      $rect = $this->weekday_rect($i);
      $this->draw_line($rect->pos->x, $rect->pos->y,
                       $rect->pos->x+$rect->size->x, $rect->pos->y,
		       ($i==7) ? $red : $black);
    }
  }

  function fill_week($day_in_week)
  { global $btgrey, $black, $red;
    global $WkDay, $Months_Full, $line_off;

    $split = getdate($day_in_week);
    $monday = $day_in_week - 86400 * ((($split["wkday"]+7)-1)%7);

    $split = getdate($monday);
    $day = $split["mday"];
    $month = $split["mon"];

    $dayfont = 3;
    $topfont = 4;
    $topoff = ImageFontHeight($topfont)/2;

    if (checkdate($month, $day+6, $split["year"]))
    {
      $header = $Months_Full[$month]." ".$split["year"];
      $careful = 0;
    }
    else // note that months are 1-based, not 0-based!
    {
      $header = $Months_Full[$month]."/".$Months_Full[($month%12)+1]." ".$split["year"];
      $careful = 1;
    }

    ImageString($this->im, $topfont, $this->links+$line_off, $this->oben+$line_off, $header, $black);

    for ($i=1; $i <= 7; ++$i)
    {
      $rect = $this->weekday_rect($i);
      if ($careful && !checkdate($month, $day-1+$i, $year)) {
        ++$month;
        $day = $i - 2;
      }
      ImageString($this->im, $dayfont,
                  $rect->pos->x, $rect->pos->y + ImageFontHeight($dayfont)/2,
		  " ".$WkDay[$i]." ".($day-1+$i), ($i==7) ? $red : $black);
    }
    return $monday;
  }

  function monthday_rect ($month, $day)
  {
    global $line_off;

    $dy = ($this->unten - $this->oben) / 37;
    $x = ($month & 1) ? $this->links+3*$line_off : $this->center->x+3*$line_off;

    if ($day == 0)
      return rect(($month & 1) ? $this->links : $this->center->x,
                  $this->oben-1+3*$dy,
                  ($this->rechts - $this->links)/2, $dy);
    if ($day == 32)
      return rect((($month & 1) ? $this->links : $this->center->x) + 3*$line_off,
                  $this->oben+(2+$day)*$dy,
                  ($this->rechts - $this->links)/2 - 6*$line_off,
		  $this->unten - ($this->oben+(2+$day)*$dy));
    else
      return rect($x, $this->oben+(2+$day)*$dy,
                  ($this->rechts - $this->links)/2 - 6*$line_off, $dy);
  }

  function draw_month() {
    global $red, $black, $grey;
    global $line_off;

    for ($month = 0; $month <= 1; ++$month)
    {
      // Top delimiting line above 1st day
      $rect = $this->monthday_rect($month,0);
      $this->draw_line($rect->pos->x, $rect->pos->y,
                       $rect->pos->x+$rect->size->x, $rect->pos->y,
                       $black);
      $this->draw_line($rect->pos->x, $rect->pos->y-1,
                       $rect->pos->x+$rect->size->x, $rect->pos->y-1,
                       $black);

      for ($i=1; $i <= 31; ++$i)
      {
        $rect = $this->monthday_rect($month,$i);
        $this->draw_line($rect->pos->x, $rect->pos->y+$rect->size->y,
                         $rect->pos->x+$rect->size->x, $rect->pos->y+$rect->size->y,
		         $grey);
      }
    }
  }

  function fill_month($day_in_week)
  { global $btgrey, $black, $red, $pink;
    global $WkDay, $Months_Full, $line_off;
    global $hh_min, $hh_max;

    $split = getdate($day_in_week);
    $month = $split["mon"];
    $year = $split["year"];

    $dayfont = 1;
    $hourfont = 1;
    $topfont = 4;
    $dayoff = ImageFontWidth($dayfont)*strlen(" Fr 31 ");
    $houroff = ImageFontWidth($hourfont)*strlen("12:30");
    $hourhite = ImageFontHeight($hourfont);

    for ($sheet = 0; $sheet <= 1; ++$sheet)
    {
      // We're always putting an odd month on the left sheet,
      // so no year wrap can occur between left & right sheet.
      $header = $Months_Full[$month+$sheet]." ".$year;

      ImageString($this->im, $topfont,
                  ($sheet == 0) ? $this->links+$line_off : $this->center->x+$line_off,
		  $this->oben+$line_off, $header, $black);

      for ($day=1; $day <= 31; ++$day)
      {
        if (!checkdate($month+$sheet, $day, $year)) {
            break;
        }
        $rect = $this->monthday_rect($month+$sheet, $day);
        if (($day%7)==0)
          $this->draw_rect($rect->pos->x+$dayoff, $rect->pos->y, 
                           $rect->pos->x+$rect->size->x, $rect->pos->y+$rect->size->y,
			   $btgrey, $btgrey);
        ImageString($this->im, $dayfont,
                    $rect->pos->x, $rect->pos->y + $rect->size->y/4,
  		  " ".$WkDay[$day%7]." ".$day, (($day%7)==0) ? $red : $black);
      }
      // draw time marks
      $rect = $this->monthday_rect($month+$sheet, 32);
      for ($hh=$hh_min; $hh <= $hh_max; ++$hh)
      {
        $lbl = sprintf("%02d:00", $hh);
        ImageStringUp($this->im, $hourfont,
                      $rect->pos->x+$dayoff-$hourhite/2+($hh-$hh_min)*($rect->size->x-$dayoff)/($hh_max-$hh_min),
		      $rect->pos->y+$houroff,$lbl,$black);
      }
//      Grey background to debug the hour entries
//      $this->draw_rect($rect->pos->x+$dayoff, $rect->pos->y, 
//                       $rect->pos->x+$rect->size->x, $rect->pos->y+$rect->size->y,
//                       $btgrey, $btgrey);
    }
    return $day;
  }

};

function point($x,$y) {
     $ret = new point_t;
     $ret->set($x,$y);
     return $ret;
}

function size($x,$y) {
     $ret = new point_t;
     $ret->set($x,$y);
     return $ret;
}

function rect($x0,$y0, $x1, $y1) {
     $ret = new rect_t;
     $ret->set4($x0,$y0, $x1, $y1);
     return $ret;
}

$center = new point_t;
$center->set($width/2, $height/2);

$links  = $border;
$rechts = $width - $border;
$oben   = $border/2;
$unten  = $height - $border/2;

$im = new gifimage_t;
$im->gifimage(size($width,$height), $border, $border/2);

$transp = ImageColorAllocate($im->im, 254, 254, 254);
ImageColorTransparent($im->im, $transp);

$white = ImageColorAllocate($im->im, 255, 255, 255);
$grey   = ImageColorAllocate($im->im, 211, 211, 211);
$btgrey = ImageColorAllocate($im->im, 221, 221, 221);
$dkgrey = ImageColorAllocate($im->im, 117, 117, 117);
$black = ImageColorAllocate($im->im, 0, 0, 0);
$pink = ImageColorAllocate($im->im, 255, 160, 160);

$green = ImageColorAllocate($im->im, 0, 255, 0);
$red = ImageColorAllocate($im->im, 255, 0, 0);
$blue = ImageColorAllocate($im->im, 0, 0, 255);

$im->draw_planner_image();

// POST_data available?
if (isset($Tag_waehlen_x) && isset($Tag_waehlen_y)) {
  for ($i=1; $i <= 7; ++$i)
  {
    $rect = $im->weekday_rect($i);
    if ($rect->is_within($Tag_waehlen_x, $Tag_waehlen_y)) {
      $rect->draw($im->im, $btgrey, $btgrey);
      $im->draw_planner_rings();
      break;
    }
  }
}

if (!isset($today))
  $today = time();

//$im->draw_week();
$im->draw_month();

//$today = $im->fill_week($today);
$today = $im->fill_month($today);

  Header("Author: Martin.Kraemer@Fujitsu-Siemens.com/jfclere@apache.org");
  $debug && Header("Expires: 0");
  $debug && Header("Cache-Control: no-cache");
  $debug && Header("Pragma: no-cache");

  // Here we try the different type of possibly supported images.
  if(function_exists("imagetypes")) {
    $supported = ImageTypes();
    if ($supported & IMG_PNG) {
      Header("Content-type: image/png");
      // Header("Content-Length: " . strlen($img));
      ImagePng($im->im);
    }
    elseif ($supported & IMG_JPG) {
      Header("Content-type: image/jpeg");
      ImageJpeg($im->im,"",0.5);
    }
    elseif ($supported & IMG_GIF) {
      Header("Content-type: image/gif");
      ImageGif($im->im);
    }
  }
  elseif(function_exists("imagegif")) {
    Header("Content-type: image/gif");
    ImageGif($im->im);
  }
  elseif(function_exists("imagePng")) {
    Header("Content-type: image/png");
    ImagePng($im->im);
  }
  elseif(function_exists("imageJpeg")) {
    Header("Content-type: image/jpeg");
    ImageJpeg($im->im,"",0.5);
  }
  else
    die("No image support in this PHP server");
?>
