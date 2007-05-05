package MemoryFilehandle;
use strict;
use warnings;
use English qw( -no_match_vars );
use base 'Exporter';
use version; our $VERSION = qv('0.0.7');

our @EXPORT_OK = qw( in_memory_handle  has_in_memory_handles );

sub in_memory_handle {
   my $fh;
   eval { open $fh, '>', \$_[0] or die; };
   eval {
      require IO::String;
      $fh = IO::String->new($_[0]);
   } if $EVAL_ERROR;
   return $EVAL_ERROR ? undef : $fh;
} ## end sub in_memory_handle

sub has_in_memory_handles {
   return defined in_memory_handle(my $target);
}

1;
