package WWW::Slides::Controller::Single;
{

   use version; our $VERSION = qv('0.0.9');

   use warnings;
   use strict;
   use Carp;
   use English qw( -no_match_vars );

   use Object::InsideOut qw( WWW::Slides::Controller );

   # Module implementation here
   my @in_handle : Field    # controller handle
     : Std(Name => 'in_handle', Private => 1)
     : Arg(Name => 'in_handle', Mandatory => 1);
   my @out_handle : Field : Std(Name => 'out_handle', Private => 1)
     : Arg(Name => 'out_handle');

   sub is_alive {
      my $self = shift;
      return defined($self->get_in_handle());
   }

   sub shut_down {
      my $self = shift;
      $self->release_selector() if $self->selector();
      $self->get_in_handle()->close() if $self->get_in_handle();
      $self->set_in_handle(undef);
      $self->get_out_handle()->close() if $self->get_out_handle();
      $self->set_out_handle(undef);
      return;
   }

   sub set_selector {
      my ($self, $selector) = @_;
      $selector->add($self->get_in_handle()) if $self->is_alive();
      $self->SUPER::set_selector($selector);
      return;
   }

   sub release_selector {
      my $self = shift;
      return unless $self->is_alive();
      $self->selector()->remove($self->get_in_handle());
      return;
   }

   sub owns {
      my $self = shift;
      my ($fh) = @_;
      return unless $self->is_alive();
      return unless defined $fh;
      return $self->get_in_handle() == $fh;
   } ## end sub owns

   sub output {
      my $self = shift;
      croak 'object is not alive, no output possible'
         unless $self->is_alive();
      my $fh = $self->get_out_handle() or return;
      print {$fh} @_;
      return;
   }

   sub get_input_chunk {
      my $self = shift;
      croak 'not alive, cannot input' unless $self->is_alive();
      $self->get_in_handle()->sysread(my $newstuff, 4096);
      return unless defined $newstuff and length $newstuff;
      return $newstuff;
   }
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

WWW::Slides::Controller::Single - main base class for controllers based in I/O


=head1 VERSION

This document describes WWW::Slides::Controller::Single version 0.0.9


=head1 SYNOPSIS

   use WWW::Slides::Controller::Single;

   # See WWW::Slides::Controller::STDIO out anyway...
   my $IO_controller = WWW::Slides::Controller::Single->new(
      in_handle  => \*STDIN,
      out_handle => \*STDOUT,
   );

   # Be sure to check WWW::Slides::Controller::TCP as well,
   # life can be easier
   use IO::Socket;
   my $listener = IO::Socket->new(LocalPort => $port, Listen => 1);
   my $sock = $listener->accept();
   my $TCP_controller = WWW::Slides::Controller::Single->new(
      in_handle  => $sock,
      out_handle => $sock,
   );

  
=head1 DESCRIPTION

This module represents the main base class for building up controllers
in the WWW::Slides system. It is able to interact with WS::Talk objects
in order to pilot all the aspects of a talk (see the documentation for
L<WWW::Slides::Talk> for more info on this).

While not normally used directly, this class can still be useful when
used on its own. The main interface is through two handles, one used
for input commands, one for putting out messages regarding those
commands. The two handles can be the same (as in the case of a TCP
socket) or different (for example using the standard streams). Subclass
normally only add the needed logic to automatically set those handles
up, but they can expand functionalities, of course.

The WWW::System is talk-centric, i.e. the I<main> object is (or should
be) the WS::Talk one (it's also the only containing a C<run()> method,
so you have probably already worked this out). For these reasons, a
generic L<Controller> has two main interaction points:

=over

=item

in the first place, it provides facility for registering/releasing a
I<selector>, i.e. an object that will be (hopefully) used like a
L<IO::Select> one (ok, 99.9% of the times it I<will> be an L<IO::Select>
object). A WS::Talk uses an L<IO::Select> object to keep track of all
possible sources of input data (attendee inputs, controllers, etc.), so
registering the selector allows the controller set the right bits in
the selector itself.

While this may seem a bit contrived in our case, because there's only
a single input handle to look after, with this mechanism
the C<Controller> interface is able to deal with the possibility that
a controller handles, behind the scenes, multiple inputs. This is the
case of L<WWW::Slides::Controller::Multiple> and its main descendant
L<WWW::Slides::Controller::TCP>, so WS::Controller::Single is no
exception and adheres to this interface.

=item 

On the actual controlling side, it provides the C<execute_commands()>
method, that grabs input commands and (tries to) execute them on the
WS::Talk object. This is where the actual work is done, where the
remote API is implemented and so the piece of code that's actually
reused without any addition. Any command addition, of course, is likely 
to extend this command.

=back


=head1 INTERFACE 

As described in the previous section, the two main parts in this class
are the I<selector management> and the I<command execution> ones. But
we also have other methods, of course, like the contruction and some
general handling methods.

=head2 Object Life Management

These methods deal with the general management of object's life, like
creation, check and shutdown.

=over

=item B<new(...)>

Like all constructors in the L<Object::InsideOut> system, you have two
different ways to build up an object. All parameters are named ones,
so you have to either pass a reference to a hash, or something that
resembles a hash by its own. The recognised named parameters are the
following:

=over

=item B<in_handle> (B<mandatory>)

The input handle where the commands come from. This handle should support
any method that IO::Handle provides, so you should safely use regular
filehandles, standard streams, TCP streams and so on.


=item B<out_handle> (optional)

The output handle where command responses are sent to. If not set,
outputs are simply discarded (it's up to you decide if this is acceptable
or not).


=item B<selector> (optional)

The C<selector> object we were talking about in L<DESCRIPTION>. Unless
you know that there is some command available in other ways, you should
probably set a value for this parameter (or set it later with
C<set_selector()>, see below) otherwise you'll risk to have blocking
reads when calling C<execute_commands()> and/or C<get_commands()>.
Caveat Emptor.


=back


=item B<is_alive()>

This method tells if the object is still I<alive> or not, i.e. if it is
still able to receive commands or not. For example, if the input channel
gets closed, the object's status is set to I<not alive> (see also
C<shut_down()> below).

=item B<shut_down()>

Perform correct cleanup before object termination. This method should
probably be called by the destructor, but at the moment it's not so and
it is called when the end-of-file condition is seen in input. This
method also releases the currently registered selector invoking
C<release_selector()>.


=back


=head2 Selector Management

=over

=item B<set_selector($selector)>

Set the current C<selector>. The C<$selector> parameter should be a reference
to the C<selector> object.

In WS::Controller::Single, this method invokes:

   $selector->add($in_handle);

where C<$in_handle> is the handle where the input commands are taken from.


=item B<selector()>

Get a reference to the currently set C<selector>.


=item B<release_selector()>

Release the selector, i.e. unregisters the selector and unregisters I<from>
the selector. in WS::Controller::Single this method invokes:

   $self->selector()->remove($in_handle);

where C<$in_handle> is the handle where the input commands are taken from.


=back


=head2 Command Execution

The main command execution method is C<execute_commands()>, and clients
should normally only need this. The other methods can be used mainly for
subclassing. This whole interface is part of the "general concept" of
what a Controller should support.

=over

=item B<execute_commands($filehandle, $talk)>

Get commands from the input and execute them on the C<$talk> object.
The C<$filehandle> parameter is actually ignored in WS::Controller::Single,
because its main usage is in C<WWW::Slides::Multiple> controllers in order
to avoid repeating the C<select>ion on the managed handles.

It relies on C<get_commands()> and C<execute_command()>, so you can change
the behaviour by subclassing those methods.


=item B<get_commands()>

This method reads a chunk of data from the input filehandle (via C<sysread>)
and tries to extract as many commands as possible from them.

In the current implementation, commands are line-oriented, so each fully
formed line (i.e. up to the terminating newline) are considered commands.
Actual command parsing and extraction is done via C<parse_command()>,
which can be overridden in derived classes.

This implementation is aligned to that in L<WWW::Slides::Client::Base>, for
a list and a description of the implemented commands see its documentation.


=item B<execute_command($command, $talk)>

This method receives a C<$command> and executes it on the talk C<$talk>.

In the current implementation, C<$command> is a hash reference containing
at least the C<command> key, which points to the command name to execute.
This format is the same as the return value of C<parse_command()>.


=item B<parse_command($command_string)>

This method accepts a command in textual form C<$command_string> and
emits a command suitable for execution by C<execute_command>, i.e.
a hash reference in the current implementation.

The input C<$command_string> is currently considered a single input line,
which is split on C</\s;/> in a first pass and then on C</=/> to extract
key-value pairs which fill the output hash.

Note that the C<target> parameter, if present, is split on C</,/> and
the resulting list is put into an anonymous array.

=back


=head2 Other I/O Related Commands

=over

=item B<owns($filehandle)>

Returns true if the C<$filehandle> is managed by this object, false otherwise.
For WS::Controller::Single object, this is equivalent to say that the
object is still alive and C<$filehandle> is equal to the input handle.

=item B<output(...)>

Send output to the output handle, if set. The input list is passed to:

   $output_handle->print(...);


=back


=head1 DIAGNOSTICS

Will complete this in the future...

=for l'autore, da riempire:
   Elencate qualunque singolo errore o messaggio di avvertimento che
   il modulo pu� generare, anche quelli che non "accadranno mai".
   Includete anche una spiegazione completa di ciascuno di questi
   problemi, una o pi� possibili cause e qualunque rimedio
   suggerito.


=over

=item C<< Error message here, perhaps with %s placeholders >>

[Descrizione di un errore]

=item C<< Another error message here >>

[Descrizione di un errore]

[E cos� via...]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for l'autore, da riempire:
   Una spiegazione completa di qualunque sistema di configurazione
   utilizzato dal modulo, inclusi i nomi e le posizioni dei file di
   configurazione, il significato di ciascuna variabile di ambiente
   utilizzata e propriet� che pu� essere impostata. Queste descrizioni
   devono anche includere dettagli su eventuali linguaggi di configurazione
   utilizzati.
  
WWW::Slides::Controller::Single requires no configuration files or environment 
variables.


=head1 DEPENDENCIES

=for l'autore, da riempire:
   Una lista di tutti gli altri moduli su cui si basa questo modulo,
   incluse eventuali restrizioni sulle relative versioni, ed una
   indicazione se il modulo in questione � parte della distribuzione
   standard di Perl, parte della distribuzione del modulo o se
   deve essere installato separatamente.

None.


=head1 INCOMPATIBILITIES

=for l'autore, da riempire:
   Una lista di ciascun modulo che non pu� essere utilizzato
   congiuntamente a questo modulo. Questa condizione pu� verificarsi
   a causa di conflitti nei nomi nell'interfaccia, o per concorrenza
   nell'utilizzo delle risorse di sistema o di programma, o ancora
   a causa di limitazioni interne di Perl (ad esempio, molti dei
   moduli che utilizzano filtri al codice sorgente sono mutuamente
   incompatibili).

None reported.


=head1 BUGS AND LIMITATIONS

=for l'autore, da riempire:
   Una lista di tutti i problemi conosciuti relativi al modulo,
   insime a qualche indicazione sul fatto che tali problemi siano
   plausibilmente risolti in una versione successiva. Includete anche
   una lista delle restrizioni sulle funzionalit� fornite dal
   modulo: tipi di dati che non si � in grado di gestire, problematiche
   relative all'efficienza e le circostanze nelle quali queste possono
   sorgere, limitazioni pratiche sugli insiemi dei dati, casi
   particolari che non sono (ancora) gestiti, e cos� via.

No bugs have been reported.

Please report any bugs or feature requests through http://rt.cpan.org/


=head1 AUTHOR

Flavio Poletti  C<< <flavio [at] polettix [dot] it> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Flavio Poletti C<< <flavio [at] polettix [dot] it> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>
and L<perlgpl>.

Questo modulo � software libero: potete ridistribuirlo e/o
modificarlo negli stessi termini di Perl stesso. Vedete anche
L<perlartistic> e L<perlgpl>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=head1 NEGAZIONE DELLA GARANZIA

Poich� questo software viene dato con una licenza gratuita, non
c'� alcuna garanzia associata ad esso, ai fini e per quanto permesso
dalle leggi applicabili. A meno di quanto possa essere specificato
altrove, il proprietario e detentore del copyright fornisce questo
software "cos� com'�" senza garanzia di alcun tipo, sia essa espressa
o implicita, includendo fra l'altro (senza per� limitarsi a questo)
eventuali garanzie implicite di commerciabilit� e adeguatezza per
uno scopo particolare. L'intero rischio riguardo alla qualit� ed
alle prestazioni di questo software rimane a voi. Se il software
dovesse dimostrarsi difettoso, vi assumete tutte le responsabilit�
ed i costi per tutti i necessari servizi, riparazioni o correzioni.

In nessun caso, a meno che ci� non sia richiesto dalle leggi vigenti
o sia regolato da un accordo scritto, alcuno dei detentori del diritto
di copyright, o qualunque altra parte che possa modificare, o redistribuire
questo software cos� come consentito dalla licenza di cui sopra, potr�
essere considerato responsabile nei vostri confronti per danni, ivi
inclusi danni generali, speciali, incidentali o conseguenziali, derivanti
dall'utilizzo o dall'incapacit� di utilizzo di questo software. Ci�
include, a puro titolo di esempio e senza limitarsi ad essi, la perdita
di dati, l'alterazione involontaria o indesiderata di dati, le perdite
sostenute da voi o da terze parti o un fallimento del software ad
operare con un qualsivoglia altro software. Tale negazione di garanzia
rimane in essere anche se i dententori del copyright, o qualsiasi altra
parte, � stata avvisata della possibilit� di tali danneggiamenti.

Se decidete di utilizzare questo software, lo fate a vostro rischio
e pericolo. Se pensate che i termini di questa negazione di garanzia
non si confacciano alle vostre esigenze, o al vostro modo di
considerare un software, o ancora al modo in cui avete sempre trattato
software di terze parti, non usatelo. Se lo usate, accettate espressamente
questa negazione di garanzia e la piena responsabilit� per qualsiasi
tipo di danno, di qualsiasi natura, possa derivarne.

=cut
