package JSON::Karabiner ;

use strict;
use warnings;
use JSON;
use Carp;
use File::HomeDir;
use JSON::Karabiner::Rule;

sub new {
  my $class = shift;
  my $title = shift;
  my $file = shift;
  my $opts = shift;

  if ($opts) {
    if (ref $opts ne 'HASH') {
      croak 'Options must be passed as a hash reference.';
    }
  }
  croak 'JSON::Karabiner constructor requires a title for the modification.' if !$title;
  croak 'JSON::Karabiner constructor requires a file name.' if !$file;
  croak 'File names are required to have a .json extenstion' if $file !~ /\.json$/;
  my $home = File::HomeDir->my_home;
  my $self = {
    _file => $file,
    _mod_file_dir => $opts->{mod_file_dir} || "$home/.config/karabiner/assets/complex_modifications/",
    _karabiner => { title => $title, rules => [] },
    _fake_write_flag => 0,
    _rule_obj => '',
  };
  if (!-d $self->{_mod_file_dir}) {
    if ($opts->{mod_file_dir}) {
      croak "The directory you attempted to set with the 'mod_file_dir' option does not exist.\n\n";
    } else {
      croak "The default directory for storing complex modifications does not exist. Do you have Karabiner-Elements installed? Is it installed with a non-standard configuration? Try setting the location of the directory manually with the 'mod_file_dir' option. Consult this module's documentation for more information with using the 'perldoc JSON::Karabiner' command in the terminal.\n\n" unless $ENV{HARNESS_ACTIVE};
    }
  }
  bless $self, $class;
  { no warnings 'once'; $main::has_delayed_action = ''; }
  return $self;
}

# used by test scripts
sub _fake_write_file {
  my $s = shift;
  $s->{_fake_write_flag} = 1;
  $s->write_file;
  $s->{_fake_write_flag} = 0;
}

sub write_file {

  my $s = shift;
  my $using_dsl = ((caller(0))[0] eq 'JSON::Karabiner::Manipulator');
  my $file = $s->{_file};
  my $dir = $s->{_mod_file_dir};
  my $destination = $dir . $file;

  if ($using_dsl) {
    my $rule = $s->{_karabiner}{rules};
    if (!%main::saved_manips) {
      %main::saved_manips = ();
      { no warnings 'once'; $main::last_manip_set = ''; }
    }
    foreach my $r (@$rule) {
      my $current_manip_set = $r->{description};
      { no warnings 'once'; $main::manip_sets{$current_manip_set}{description} = $current_manip_set; }
      if (! defined $main::manip_sets{$current_manip_set}{manipulators}) {
        $main::manip_sets{$current_manip_set}{manipulators} = [];
      }
      foreach my $manip ($r->{manipulators}) {
        push @main::saved_manips, @{$manip};
        push @{$main::manip_sets{$current_manip_set}{manipulators}}, @{$manip};
      }
    }

    my $count = 0;
    foreach my $k (keys %main::manip_sets) {
      my $manipulators = $main::manip_sets{$k}{manipulators};
      my $description = $main::manip_sets{$k}{description};
      my $new_hash = { manipulators => $manipulators, description => $description };
      $s->{_karabiner}->{rules}[$count++] = $new_hash;

    }

  }
  my $json = $s->_get_json();

  #TODO ensure it works with utf8
  if (!$s->{_fake_write_flag}) {
    open (FH, '>', $destination) or die 'Could not open file for writing.';
    print FH $json;
    close FH;
  }

  print "Your rules were successfully written to:\n\n $destination.\n\nOpen Karabiner-Elements to import the new rules you have generated.\n\nIf your rules do not appear, please report the issue to our issue queue:\n\nhttps://github.com/sdondley/JSON-Karabiner/issues \n\n"
}

sub _get_json {
  my $s = shift;
  my $json = JSON->new();
  $json = $json->convert_blessed();
  return $json->canonical->pretty->encode($s->{_karabiner});
}

sub add_rule {
  my $s = shift;
  my $desc = shift;
  croak "No description passed to rule." if !$desc;
  my $rule = JSON::Karabiner::Rule->new($desc);
  $s->_add_rule($rule);
  $s->{_rule_object} = $rule;
  return $rule;
}

sub _add_rule {
  my $s = shift;
  my $rule = shift;
  push @{$s->{_karabiner}{rules}}, $rule;
}

sub _check_if_file_exits {

}

sub _dump_json {
  my $s = shift;
  my $json = JSON->new();
  $json = $json->convert_blessed();

  # suppress validity tests
  $s->{_rule_object}->_disable_validity_tests();

  use Data::Dumper qw(Dumper);
  print Dumper $json->canonical->pretty->encode($s->{_karabiner});

  # renable validity tests
  $s->{_rule_object}->_enable_validity_tests();
}


# ABSTRACT: easy JSON code generation for Karabiner-Elements

1;

__END__

=head1 OVERVIEW

Write and generate Karabiner json effortlessly using a simple Perl script.

Karabiner is a MacOS application for modifying key and button strokes.

=head1 INSTALLATION

This software is written in Perl and bundled as a package called C<JSON::Karabiner>.
If you are not familiar with installing Perl packages, don't worry. Just follow
this simple two-step process:

=head3 Step 1: Ensure the C<cpanm> command is installed:

Run the following command from a terminal window:

  C<which cpanm>

If the terminal reponds with the path to C<cpanm>, proceed to Step 2.

If the C<cpanm> command is not installed, copy and paste one of the following
three commands into your terminal window to install it:

  # Option 1: Install to system Perl
  curl -L https://cpanmin.us | perl - --sudo App::cpanminus

  # Option 2: Install to local Perl (you must have a local version of Perl already installed)
  curl -L https://cpanmin.us | perl - App::cpanminus

  # Option 3: Install as standalone executable
  cd ~/bin && curl -L https://cpanmin.us/ -o cpanm && chmod +x cpanm

If you are unsure what the best option is for installing C<cpanm>, L<consult its
documentation for more
help.|https://metacpan.org/pod/App::cpanminus#INSTALLATION>.

=head3 Step 2: Install the C<JSON::Karabiner> package

Now issue the following comamdn to install the software:

  cpanm JSON::Karabiner

After issuing the C<cpanm> command above, you should see a success message. If so,
you can start using cpanm JSON::Karabiner and start using it in local Perl scripts
you write. If you get errors about lack of permissions, try running:

  sudo cpanm JSON::Karabiner

If you still get weird errors, it may be a bug. Please report your issue to the
L<issue queue|https://github.com/sdondley/JSON-Karabiner/issues>.

=head4 Other install methods

This module can also be installed using the older C<cpan> command that is
already on your Mac. See L<how to install CPAN
modules|https://www.cpan.org/modules/INSTALL.html> for more information.

=head1 SYNOPSIS

Below is an executable perl script that generates a json file that can be read
by by L<Karabiner-Elements|https://karabiner-elements.pqrs.org>. You can copy
and paste this code to your local machine,modify it if you wish, and execute it.
Note that you must first install the C<JSON::Karabiner> package
(see the L</"INSTALLATION"> section below).

This script is easy to understand even if you have no experience with Perl, or
any programming langauge, for that matter. But don't hesitate to L<file an
issue|https://github.com/sdondley/JSON-Karabiner/issues> if you need
asssistance.

  #!/usr/bin/env perl                # shebang line so this program is opened with perl interpreter
  use JSON::Karabiner::Manipulator;  # The JSON::Karabiner Perl package must be installed on your machine

  # Create a new manipulator object with a description and the file you want to save it to
  new_manipulator('a-s-d to show character viewer', 'my_awesome_karabiner_mod.json');

  # Add a from action to the manipulator:
  add_action 'from';

  # Add behaviors to the action:
  add_simultaneous 'a', 's', 'd';
  add_optional_modifiers 'any';

  # Add a "to" action to the manipulator:
  add_action 'to';

  # Tell the "to" action what to do
  add_key_code('spacebar');
  add_modifiers('control', 'command');

  # Done! Now it's time to write the file and give the rule a title:
  write_file('Emoji Character Viewer');

Save this code to a file on your computer and be sure to make the script executable with:

  chmod 744 your_file_name.pl

Then execute this script with:

  ./your_file_name.pl

from the same directory where this script is saved.

After this script is run, a json file called my_awesome_karabiner_mod.json
should now be sitting in the assets/complex_modifications directory. Open
the Karabiner-Elements app on your Mac to install the new rule.

Ready to give is try? Follow the L</"INSTALLATION"> instructions to get started.

=head1 DESCRIPTION

Karabiner stores rules for its modifications in a file using a data format
known as JSON which is painstaking to edit and create. JSON::Karabiner eases the
pain by letting Perl write the JSON for you. If you aren't familar with Perl, or
programming at all, don't worry. There are examples provided that you can follow
so no programming knowledge is necessary. The 10 or 20 minutes you spend
learning how to install and use this module will pay off in spades.

A Karabiner JSON complex modification file stores the rules for modifying the keyboard
in a data structure called the "manipulators." Therefore, most of methods you
write will add data to the manipulator data structure. C<JSON::Karabiner> can then
write the JSON to a file and then you can load the rules you've written using
the Kabrabiner-Elements program.

Below are descriptions of the methods used on manipulators.

=over 4

=item C<add_action> method

for adding the from/to actions to the manipulator

=item C<add_condition> method

for adding manipulator conditions

=item C<add_parameter> method

for adding maniplator parameters

=item C<add_description> method

for adding a description to the manipulator

=back

After you run a C<add_action> or C<add_condition> method, you will need to run
additional methods that will be applied to the last action or condition you
added.

It will be very helpful if you have a basic familiarity with the Karabiner
manipulator definition to gain an understanding of which methods to run. See the
L<Karabiner complex_modification manipulator
documentation|https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/>
for more information.

=head2 DSL Interface

As of version 0.011, JSON::Karabiner moved to a DSL (domain specific language)
interface to make writing scripts even easier. Please see the L</SYNOPSIS>
for an example of how to use the DSL. Note that the older object-oriented interface,
though currently deprecated and undocumented, is still fully funcitonal (or
should be, in theory).

=head2 How to Use the DSL Interface

There are two parts to a DSL inteface: the method and the list of arguments you
are passing to the method. You can think of the method as the action you want to
take and the arguments as the data "nouns" you want to store or process.

Methods that add data to the manipulator begin with C<add_> followed by
a string of characters that corresponds to properties outlined in the Karabiner
documentation. For example, to add a C<key_code> property, you write:

  add_key_code 't';

Here, the action is C<add_key_code> and the data is the character "t". Note that
the method call must end in a semicolon. Each argument you pass must be
surrounded by apostrophes. Or, if you want to avoid the pain of having to type
apostrophers, you can use Perl's C<qw> function:

  add_modifiers qw(control shift command);

It bears repeating that methods that apply to actions (or condtions) are automatically
assigned to the B<most recent action (or condition) that was created>.
In other words, if your have:

  add_action 'to';
  add_action 'from';
  add_key_code 'x';

The key code will be added to the C<from> action. If you wish apply it to the C<to>
action, simply move the C<add_key_code> line immediately after the C<to> action. This
same rule applies for condtions as well as actions. Any method that adds data
to a condtion will get added to the last condition created.

=head3 List of Methods for Actions

The following methods apply to actions (e.g. C<from>, C<to>, C<to_if_alone> etc.)

=head4 From methods

The following methods are for the C<from> action:

=over 4

=item add_any

=item add_consumer_key_code

=item add_key_code

=item add_mandatory_modifiers

=item add_optional_modifiers

=item add_pointing_button

=item add_simultaneous

=item add_simultaneous_options


=back

=head4 To methods

The following methods are for the C<to> action (includes C<to_if_alone>, C<to_if_held_down>
C<to_after_key_up>, C<to_delayed_if_invoked>, C<to_delayed_if_canceled>):

=over 4

=item add_consumer_key_code

=item add_key_code

=item add_modifiers

=item add_mouse_key

=item add_pointing_button

=item add_select_input_source

=item add_set_variable

=item add_shell_command

=back

=head3 List of Methods for Conditions

The following methods will add data to the most recently created condition in the script.

=over 4

=item add_bundle_identifiers

=item add_description

=item add_file_path

=item add_identifier

=item add_input_source

=item add_keyboard_types

=item add_value

=item add_variable

=back

For further details on each these methods, including the arguments they take,
please see the appropriate perl doc page:

=over 4

=item L<from action|JSON::Karabiner::Manipulator::Actions::From>

=item L<to action|JSON::Karabiner::Manipulator::Actions::To>

=item L<conditions|JSON::Karabiner::Manipulator::Conditions>

=back

=head3 Multiple manipulators

The DSL interface makes it easy to include multiple manipulator in a single rule.
Follow this patter:

  new_manipulator('Turn x key into y key', 'name_of_file.json');

  ... Run methods for above manipulator here ...

  write_file('Name of Rule');

  new_manipulator('Turn a key into by key', 'name_of_file.json');

  ... Run methods for the second manipulator here ...

  write_file('');

  ... Add N more manipulators here ...

Just be sure the manipulators all have the same file name so they will be
included in the same file.

Notice that only the first C<write_file> method requires the name of the rule
to be passed. Subsequent calls to C<write_file> will inherit the title from
the first manipulator written.

=head3 Writing to the JSON file

As shown in the example above, a C<write_file> call must be made for each
manipulator in your script to have it included in the JSON file. The title is
required to be supplied to the first manipulator. Subsequent C<write_file>
calls will use the first title.

=head1 METHODS

=head2 new_manipulator($maniuplator_description, $file_name, [ { mod_file_dir => '/path_/to/dir' } ])

Example usage:

  new_manipulator 'Double tap shift for ⌘-f', 'double-taps.json', { mod_file_dir => '/some/dir' };

This method creates a new manipulator. It must be called before adding
actions, condtisions and parameters. The method takes two required arguments: a
description of the manipulator and the name of the file you with to save it to.
A third argument for passing options to the maniplator, is optional.

=head3 Manipulator description

The description will be displayed in the Karabiner-Elements application. The
description is used to let you know which rule is getting enabled/disabled. You
should be descriptive here.

=head3 File name

This is the name of the file your manipulator will be saved in. If this file name
is the same for other manipulators, those manipulators will be stored together
in the same file. This file should end with the ".json" file extension.

=head3 Options

Only one option is available, C<mod_file_dir>. This is needed only if you want to
save your json file to a place other than the default, C<~/.config/karabiner/assets/complex_modifications>.

Note that options are passed as an anonymous has reference. What this means
to you is that you have to place this option inside curly braces per the example
above.

=head2 add_action($type)

There are seven different types of actions you can add:

  add_action('from');
  add_action('to');
  add_action('to_if_alone');
  add_action('to_if_held_down');
  add_action('to_after_key_up');
  add_action('to_delayed_if_invoked');
  add_action('to_delayed_if_canceled');

The most frequently uses actions are the first four listed above. You must create a C<from> action to
your manipulator. The C<from> action contains the keystrokes you want to modify.
The other C<to> actions describe what the C<from> keystroke actions will be changed
into. See the Karabiner documentation for more information on these actions.

Once these actions are created, you may run methods to that add additional data
to them to modify their behavior. Consult the documentation for the different
actions for a listing and description of those methods:

=over 4

=item L<JSON::Karabiner::Manipulator::Actions::From>

=item L<JSON::Karabiner::Manipulator::Actions::To>

=back

=head2 add_condition($type)

Conditions make the modification conditional upon some other bit of data. You
can add the following types of conditions:

  add_condition('device_if');
  add_condition('device_unless')
  add_condition('event_changed_if')
  add_condition('frontmost_application_if')
  add_condition('frontmost_application_unless')
  add_condition('input_source_if')
  add_condition('input_source_unless')
  add_condition('keyboard_type_if')
  add_condition('variable_if')
  add_condition('variable_unless')

Once the conditions are created, you can add data with additional methods.
See the additional documenation for these methods and the arguments they accept:

L<JSON::Karabiner::Manipulator::Conditions>

Consult the Karabiner documentation to understand how they modifty the behavior
of the actions.

=head2 add_parameter($name, $value)

Parameters are used by Karabiner to change various timing aspects of the actions. Four
different parameters may be set:

  add_parameter('to_if_alone_timeout_milliseconds', 500);
  add_parameter('to_if_held_down_threshold_milliseconds, 500);
  add_parameter('to_delayed_action_delay_milliseconds, 250);
  add_parameter('simultaneous_threshold_milliseconds, 50);

See the Karabiner documentation for more details.

=head2 add_description($description)

Adds a description to the manipulator data structure:

  add_description('This turns a period into a hyper key.');

This description is not visible inside Karabiner-Elements apps.

=head2 write_file($title)

Example usage:

  write_file('My Hotkeys');

This method outputs the most recently created manipulator object to the file
set by the manipulator. If other manipulators exist in your script and share
the same file name, they will be merged together into the same file.

This method will overwrite pre-existing files with the same name without
warning, so be sure the file name is unique if you don't want this to happen.

The title is a require field, but only for the first manipulator saved. If the
title is left blank for later manipulators, they will share the same title as
the first. This allows you to group manipulators under the same title in the
Karabiner-Elements interface.

=head1 Development Status

This module is currently in alpha release and is actively supported and
maintained. Suggestion for improvement are welcome. It is known to generate
valid JSON that allow Karabiner to import rules from the file generated for at
least simple cases and probably more advanced cases as well.

Many improvements are in the works. Please watch us on GitHub.

=head1 BUGS AND LIMITATIONS

Though this software is still in an alpha state, it should be able to generate
code for any property with the exception of the C<to_after_key_up> key/value use
for the simultaneous options behavior due to uncertainty in how this should be
implemented. If you need this feature, generate your json code using this script
as you normally would and then manually edit it to insert the necessary json
code.

=head1 SEE ALSO

=over 4

=item L<Karabiner Elements Home Page|https://karabiner-elements.pqrs.org>

=item L<Karabiner Elements Reference Manual|Documentation>

=back
