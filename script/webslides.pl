#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/../lib";

use WWW::Slides::SlideShow;
use WWW::Slides::Talk;
use WWW::Slides::Controller::STDIO;
use WWW::Slides::Controller::TCP;

my $slide_show = WWW::Slides::SlideShow->new();
$slide_show->read(\*DATA);

my $controller;
if (my $port = shift) {
   $controller = WWW::Slides::Controller::TCP->new(port => $port);
}
else {
   $controller = WWW::Slides::Controller::STDIO->new();
}

my $talk = WWW::Slides::Talk->new(
   controller => $controller,
   port       => 50505,
   slide_show => $slide_show,
   must_book  => shift,
);

$talk->run();


__END__
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
                      "http://www.w3.org/TR/html4/loose.dtd">
<html>
   <head>
      <title>Here I come!</title>
   </head>
   <body>

        <div id="slide0">
            <h1>This is slide 1</h1>
Here you can find the contents for slide #1. You can insert images:
<p>
<img src="http://www.polettix.it/cgi-bin/wiki.pl/download/PerlFlowers.png"
     alt="Perl flowers" title="Perl flowers">
<p>as well as other elements:
<ul>
<li>a</li>
<li>simple</li>
<li>list</li>
</ul>

         </div>

        <div id="slide1">

<h1>This is slide 2</h1>
The contents are completely different here.
<hr>
<p>
<img src="http://www.polettix.it/cgi-bin/wiki.pl/download/Soffietto-soluzione.png"
     alt="solution" title="solution">

         </div>

        <div id="slide2">

<h1>This is slide 3</h1>
The contents are completely different here, with respect to the other
two pages.
<hr>
<p>
<img src="http://www.polettix.it/cgi-bin/wiki.pl/download/Casa.png"
     alt="solution" title="solution">
<p>I live here!

         </div>

   </body>
</html>
