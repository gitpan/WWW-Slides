# vim: filetype=perl :
use strict;
use warnings;

use Test::More tests => 7;    # last test to print
use Test::Exception;

my $module = 'WWW::Slides::SlideShow';

require_ok($module);

my $slide_show = $module->new();
lives_ok { $slide_show->read(\*DATA) } 'correctly reads from filehandle';
is($slide_show->filename(), '<filehandle>', 'filename set');

seek DATA, 0, 0;
my $data = do { local $/; <DATA> };

lives_ok { $slide_show->read(\$data) } 'correctly reads from string';
is($slide_show->filename(), '<string>', 'filename set');

SKIP: {
   eval 'use File::Temp';
   skip('because File::Temp required for file read', 1) if $@;

   my ($fh, $filename) = eval { File::Temp::tempfile() };
   skip('because I need to create a file for file read', 1) if $@;

   print {$fh} $data;
   close $fh;

   lives_ok { $slide_show->read($filename) } 'correctly reads from file';
   is($slide_show->filename(), $filename, 'filename set');
} ## end SKIP:

__DATA__
<PREAMBLE STUFF HERE>
<div id="slide1">
</div>
<div id="slide2">
</div>
<div id="slide3">
</div>
