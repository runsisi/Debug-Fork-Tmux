#
# This file is part of Debug-Fork-Tmux
#
# This software is Copyright (c) 2013 by Peter Vereshagin.
#
# This is free software, licensed under:
#
#   The (three-clause) BSD License
#
# ABSTRACT: Makes fork() in debugger to open a new Tmux window
package Debug::Fork::Tmux;

# Helps you to behave
use strict;
use warnings;

our $VERSION = '1.000012';    # VERSION
#
### MODULES ###
#
# Glues up path components
use File::Spec;

# Resolves up symlinks
use Cwd;

# Dioes in a nicer way
use Carp;

# Reads configuration
use Debug::Fork::Tmux::Config;

# Makes constants possible
use Const::Fast;

### CONSTANTS ###
#

### SUBS ###
#
# Function
# Gets the tty name, sets the $DB::fork_TTY to it and returns it.
# Takes     :   n/a
# Requires  :   DB, Debug::Fork::Tmux
# Overrides :   DB::get_fork_TTY()
# Changes   :   $DB::fork_TTY
# Returns   :   Str tty name $DB::fork_TTY
sub DB::get_fork_TTY {

    # Create a TTY
    my $tty_name = Debug::Fork::Tmux::_spawn_tty();

    # Output the name both to a variable and to the caller
    no warnings qw/once/;
    $DB::fork_TTY = $tty_name;
    return $tty_name;
}

# Function
# Spawns a TTY and returns its name
# Takes     :   n/a
# Returns   :   Str tty name
sub _spawn_tty {

    # Create window and get its tty name
    my $window_id = _tmux_new_window();
    my $tty_name  = _tmux_window_tty($window_id);

    return $tty_name;
}

# Function
# Creates new 'tmux' window  and returns its id/number
# Takes     :   n/a
# Depends   :   On 'tmux_fqfn', 'tmux_neww', 'tmux_neww_exec' configuration
#               parameters
# Returns   :   Str id/number of the created 'tmux' window
sub _tmux_new_window {
    my @cmd_to_read = (
        Debug::Fork::Tmux::Config->get_config('tmux_fqfn'),
        split(
            /\s+/, Debug::Fork::Tmux::Config->get_config('tmux_cmd_neww')
        ),
        Debug::Fork::Tmux::Config->get_config('tmux_cmd_neww_exec'),
    );

    my $window_id = _read_from_cmd(@cmd_to_read);

    return $window_id;
}

# Function
# Gets a 'tty' name from 'tmux's window id/number
# Takes     :   Str 'tmux' window id/number
# Depends   :   On 'tmux_fqfn', 'tmux_cmd_tty' configuration parameters
# Returns   :   Str 'tty' device name of the 'tmux' window
sub _tmux_window_tty {
    my $window_id = shift;

    # Concatenate the 'tmux' command and read its output
    my @cmd_to_read = (
        Debug::Fork::Tmux::Config->get_config('tmux_fqfn'),
        split( /\s+/, Debug::Fork::Tmux::Config->get_config('tmux_cmd_tty') ),
        $window_id,
    );
    my @tmux_cmd = (@cmd_to_read);
    my $tty_name = _read_from_cmd(@tmux_cmd);

    return $tty_name;
}

# Function
# Reads the output of a command supplied with parameters as the argument(s)
# and returns its output.
# Takes     :   Array[Str] command and its parameters
# Throws    :   If command failed or the output is not the non-empty Str
#               single line
# Returns   :   Output of the command supplied with parameters as arguments
sub _read_from_cmd {
    my @cmd_and_args = @_;

    # Open the pipe to read
    _croak_on_cmd( @cmd_and_args, "failed opening command: $!" )
        unless open my $cmd_output_fh => '-|',
        @cmd_and_args;

    # Read a line from the command
    _croak_on_cmd( @cmd_and_args, "didn't write a line" )
        unless defined($cmd_output_fh)
        and ( 0 != $cmd_output_fh )
        and my $cmd_out = <$cmd_output_fh>;

    # If still a byte is readable then die as the file handle should be
    # closed already
    my $read_rv = read $cmd_output_fh => my $buf, 1;
    _croak_on_cmd( @cmd_and_args, "failed reading command: $!/$buf" )
        unless defined $read_rv;
    _croak_on_cmd( @cmd_and_args, "did not finish: $buf" )
        unless 0 == $read_rv;

    # Die on empty output
    chomp $cmd_out;
    _croak_on_cmd( @cmd_and_args, "provided empty string" )
        unless length $cmd_out;

    return $cmd_out;
}

# Function
# Croaks nicely on the command with an explanation based on arguments and $?
# Takes     :   Array[Str] system command, its arguments, and an explanation
#               on the situation when the command failed
# Requires  :   Carp
# Depends   :   On $? global variable set by system command failure
# Throws    :   Always
# Returns   :   n/a
sub _croak_on_cmd {
    my @cmd_args_msg = @_;

    if ( defined $? ) {
        my $msg = '';

        # Depending on $?, add it to the death note
        # Command may be a not-executable
        if ( $? == -1 ) {
            $msg = "failed to execute: $!";
        }

        # Command can be killed
        elsif ( $? & 127 ) {
            $msg = sprintf "child died with signal %d, %s coredump",
                ( $? & 127 ), ( $? & 128 ) ? 'with' : 'without';
        }

        # Command may return the exit code for clearance
        else {
            $msg = sprintf "child exited with value %d", $? >> 8;
        }

        # And the message can be returned as an appendix to the original
        # arguments
        push @cmd_args_msg, $msg;
    }

    # Report the datails via the Carp
    my $croak_msg = "The command " . join ' ' => @cmd_args_msg;
    croak($croak_msg);
}

# Returns true to require()
1;

__END__

=pod

=head1 NAME

Debug::Fork::Tmux - Makes fork() in debugger to open a new Tmux window

=head1 VERSION

This documentation refers to the module contained in the distribution C<Debug-Fork-Tmux> version 1.000012.

=head1 SYNOPSIS

    #!/usr/bin/perl -d
    #
    # ABSTRACT: Debug the fork()-contained code in this file
    #
    ## Works only under Tmux: http://tmux.sf.net
    #
    # Make fork()s debuggable with Tmux
    use Debug::Fork::Tmux;

    # See what happens in your debugger then...
    fork;

=head1 DESCRIPTION

Make sure you have the running C<Tmux> window manager:

    $ tmux

=over

=item * Only C<Tmux> version 1.6 and higher works with C<Debug::Fork::Tmux>.
See L</DEPENDENCIES>.

=item * It is not necessary to run this under C<Tmux>, see L</Attaching to
the other C<Tmux> session>.

=back

Then the real usage example of this module is:

    $ perl -MDebug::Fork::Tmux -d your_script.pl

As Perl's standard debugger requires additional code to be written and used
when the debugged Perl program use the L<fork()|perlfunc/fork> built-in.

This module is about to solve the trouble which is used to be observed like
this:

  ######### Forked, but do not know how to create a new TTY. #########
  Since two debuggers fight for the same TTY, input is severely entangled.

  I know how to switch the output to a different window in xterms, OS/2
  consoles, and Mac OS X Terminal.app only.  For a manual switch, put the
  name of the created TTY in $DB::fork_TTY, or define a function
  DB::get_fork_TTY() returning this.

  On UNIX-like systems one can get the name of a TTY for the given window
  by typing tty, and disconnect the shell from TTY by sleep 1000000.

All of that is about getting the pseudo-terminal device for another part of
user interface. This is probably why only the C<GUI>s are mentioned here:
C<OS/2> 'Command Prompt', C<Mac OS X>'s C<Terminal.app> and an C<xterm>. For
those of you who develop server-side stuff it should be known that keeping
C<GUI> on the server is far from always to be available as an option no
matter if it's a production or a development environment.

The most ridiculous for every C<TUI> (the C<ssh> particularly) user is that
the pseudo-terminal device isn't that much about C<GUI>s by its nature so
the problem behind the bars of the L<perl5db.pl> report (see more detailed
problem description at the L<PerlMonks
thread|http://perlmonks.org/?node_id=128283>) is the consoles management.
It's a kind of a tricky, for example, to start the next C<ssh> session
initiated from the machine serving as an C<sshd> server for the existing
session.

Thus we kind of have to give a chance to the consoles management with a
software capable to run on a server machine without as much dependencies as
an C<xterm>. This module is a try to pick the L<Tmux|http://tmux.sf.net>
windows manager for such a task.

Because of highly-developed scripting capabilities of C<Tmux> any user can
supply the 'window' or a 'pane' to Perl's debugger making it suitable to
debug the separate process in a different C<UI> instance. Also this adds the
features like C<groupware>: imagine that your mate can debug the process
you've just C<fork()ed> by mean of attaching the same C<tmux> you are
running on a server. While you keep working on a process that called a
C<fork()>.

=head1 SUBROUTINES/METHODS

All of the following are functions:

=head2 PUBLIC

=head3 C<DB::get_fork_TTY()>

Finds new C<TTY> for the C<fork()>ed process.

Takes no arguments. Returns C<Str> name of the C<tty> device of the <tmux>'s
new window created for the debugger's new process.

Sets the C<$DB::fork_TTY> to the same C<Str> value.

=head2 PRIVATE

=head3 C<_spawn_tty()>

Creates a C<TTY> device and returns C<Str> its name.

=head3 C<_tmux_new_window()>

Creates a given C<tmux> window and returns C<Str> its id/number.

=head3 C<_tmux_window_tty( $window_id )>

Finds a given C<tmux> window's tty name and returns its C<Str> name based on
a given window id/number typically from L</_tmux_new_window()>.

=head3 C<_read_from_cmd( $cmd =E<gt> @args )>

Takes the list containing the C<Str> L<system()|perlfunc/system> command and
C<Array> its arguments and executes it. Reads C<Str> the output and returns it.
Throws if no output or if the command failed.

=head3 C<_croak_on_cmd( $cmd =E<gt> @args, $happen )>

Takes the C<Str> command, C<Array> its arguments and C<Str> the reason of
its failure, examines the C<$?> and dies with explanation on the
L<system()|perlfunc/system> command failure.

=head1 CONFIGURATION AND ENVIRONMENT

The module requires the L<Tmux|http://tmux.sf.net> window manager for the
console to be present in the system.

This means that it requires the C<Unix>-like operating system not only to
have a L<fork> implemented and a C<TTY> device name supplement but the
system should have Tmux up and running.

Therefore C<Cygwin> for example isn't in at this moment, see the
L<explanation|http://permalink.gmane.org/gmane.comp.terminal-emulators.tmux.user/1354>
why.

Configuration is made via environment variables, the default is taken for
each of them with no such variable is set in the environment:

=head2 C<DFTMUX_FQFN>

The C<tmux> binary name with the full path.

Default :   The first of those for executable to exist:

=over

=item C<PATH> environment variable contents

=item Path to the Perl binary interpreter

=item Current directory

=back

and just the C<tmux> as a fallback if none of above is the location of the
C<tmux> executable file.

=head2 C<DFTMUX_CMD_NEWW>

The L<system()|perlfunc/system> arguments for a C<tmux>
command for opening a new window and with output of a window address from
C<tmux>. String is sliced by spaces to be a list of parameters.

Default :  C<neww -P>

=head2 C<DFTMUX_CMD_NEWW_EXEC>

The L<system()|perlfunc/system> or a shell command to be given to the
C<DFTMUX_CMD_NEWW> command to be executed in a brand new created
window. It should wait unexpectedly and do nothing till the debugger
catches the device and puts in into the proper use.

Default :  C<sleep 1000000>

=head2 C<DFTMUX_CMD_TTY>

Command- line  parameter(s) for a  C<tmux> command to find a C<tty> name in
the output. The string is sliced then by spaces. The C<tmux>'s window
address is added then as the very last argument.

Default :  C<lsp -F #{pane_tty} -t>

=head2 Earlier versions' C<SPUNGE_*> environment variables

Till v1.000009 the module was controlled by the environment variables like
C<SPUNGE_TMUX_FQDN>. Those are deprecated and should be replaced in your
configuration(s) onto the C<DFTMUX_>-prefixed ones.

=head2 Attaching to the other C<Tmux> session

For the case you can not or don't want to use the current C<tmux> session
you are running in, you may want to have the separate C<tmux> server up and
running and use its windows or panes to be created. This can be done by mean
of prepending the correct C<-L> or C<-S> switch to the start of the every of
the command-line parameters string to be used, for example:

    $ DFTMUX_CMD_NEWW="-L default neww -P" \
    > DFTMUX_CMD_TTY="-L default lsp -F #{pane_tty} -t" \
    > perl -MDebug::Fork::Tmux -d your_script.pl

=head1 DIAGNOSTICS

=over

=item * C<The command ...>

Typically the error message starts with the command the L<Debug::Fork::Tmux> tried
to execute, including the command's arguments.

=item * C<failed opening command: ...>

The command was not taken by the system as an executable binary file.

=item * C<... didn't write a line>

=item * C<failed reading command: ...>

Command did not output exactly one line of the text.

=item * C<... did not finish>

Command outputs more than one line of the text.

=item * C<provided empty string>

Command outputs exactly one line of the text and the line is empty.

=item * C<failed to execute: ...>

There was failure executing the command

=item * C<child died with(out) signal X, Y coredump>

Command was killed by the signal X and the coredump is (not) located in Y.

=item * C<child exited with value X>

Command was not failed but there are reasons to throw an error like the
wrong command's output.

=back

=head1 DEPENDENCIES

* C<Perl 5.8.9+>
is available from L<The Perl website|http://www.perl.org>

* L<Config>, L<Cwd>, L<DB>, L<ExtUtils::MakeMaker>, L<File::Find>,
L<File::Spec>, L<File::Basename>, L<Scalar::Util>, L<Test::More> are
available in core C<Perl> distribution version 5.8.9 and later

* L<Const::Fast>
is available from C<CPAN>

* L<Module::Build>
is available in core C<Perl> distribution since version 5.9.4

* L<Sort::Versions>
is available from C<CPAN>

* L<Test::Exception>
is available from C<CPAN>

* L<Test::Most>
is available from C<CPAN>

* L<Test::Strict>
is available from C<CPAN>

* L<Env::Path>
is available from C<CPAN>

* L<autodie>
is available in core C<Perl> distribution since version 5.10.1

* C<Tmux> v1.6+
is available from L<The Tmux website|http://tmux.sourceforge.net>

Most of them can easily be found in your operating system
distribution/repository.

=head1 BUGS AND LIMITATIONS

You can make new bug reports, and view existing ones, through the
web interface at L<http://bugs.vereshagin.org/product/Debug-Fork-Tmux>.

=head1 WEB SITE

The web site of
L<Debug::Fork::Tmux|http://gitweb.vereshagin.org/Debug-Fork-Tmux/README.html> currently
consists of only one page cause it's a very small module.

You may want to visit a L<GitHub
page|https://github.com/petr999/Debug-Fork-Tmux>, too.

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Perldoc

You can find documentation for this module with the perldoc command.

  perldoc Debug::Fork::Tmux

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

MetaCPAN

A modern, open-source CPAN search engine, useful to view POD in HTML format.

L<http://metacpan.org/release/Debug-Fork-Tmux>

=item *

Search CPAN

The default CPAN search engine, useful to view POD in HTML format.

L<http://search.cpan.org/dist/Debug-Fork-Tmux>

=item *

RT: CPAN's Bug Tracker

The RT ( Request Tracker ) website is the default bug/issue tracking system for CPAN.

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Debug-Fork-Tmux>

=item *

AnnoCPAN

The AnnoCPAN is a website that allows community annotations of Perl module documentation.

L<http://annocpan.org/dist/Debug-Fork-Tmux>

=item *

CPAN Ratings

The CPAN Ratings is a website that allows community ratings and reviews of Perl modules.

L<http://cpanratings.perl.org/d/Debug-Fork-Tmux>

=item *

CPAN Forum

The CPAN Forum is a web forum for discussing Perl modules.

L<http://cpanforum.com/dist/Debug-Fork-Tmux>

=item *

CPANTS

The CPANTS is a website that analyzes the Kwalitee ( code metrics ) of a distribution.

L<http://cpants.perl.org/dist/overview/Debug-Fork-Tmux>

=item *

CPAN Testers

The CPAN Testers is a network of smokers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/D/Debug-Fork-Tmux>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=Debug-Fork-Tmux>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=Debug::Fork::Tmux>

=back

=head2 Email

You can email the author of this module at C<peter@vereshagin.org> asking for help with any problems you have.

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<peter@vereshagin.org>, or through
the web interface at L<http://bugs.vereshagin.org/product/Debug-Fork-Tmux>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<http://gitweb.vereshagin.org/Debug-Fork-Tmux>

  git clone https://github.com/petr999/Debug-Fork-Tmux.git

=head1 AUTHOR

L<Peter Vereshagin|http://vereshagin.org> <peter@vereshagin.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2013 by Peter Vereshagin.

This is free software, licensed under:

  The (three-clause) BSD License

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<Debug::Fork::Tmux::Config|Debug::Fork::Tmux::Config>

=item *

L<http://perlmonks.org/?node_id=128283|http://perlmonks.org/?node_id=128283>

=item *

L<nntp://nntp.perl.org/perl.debugger|nntp://nntp.perl.org/perl.debugger>

=item *

L<http://debugger.perl.org/|http://debugger.perl.org/>

=back

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT
WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER
PARTIES PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND,
EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE
SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME
THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE
TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
DAMAGES.

=cut
