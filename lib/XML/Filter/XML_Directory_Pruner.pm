{

=head1 NAME

XML::Filter::XML_Directory_Pruner - SAX2 filter for restricting the output of the XML::Directory::SAX

=head1 SYNOPSIS

 use XML::SAX::Writer;
 use XML::Directory::SAX;
 use XML::Filter::XML_Directory_Pruner;

 my $output = "";

 my $writer = XML::SAX::Writer->new(Output=>\$output);
 my $pruner = XML::Filter::XML_Directory_Pruner->new(Handler=>$writer);

 $pruner->exclude(matching=>"(.*)\\.ph\$");
 $pruner->include(ending=>[".pm"]);

 my $directory = XML::Directory::SAX->new(Handler=>$pruner,
                                       detail=>2,
                                       depth=>1);

 $directory->parse_dir($INC[0]);

=head1 DESCRIPTION

XML::Filter::XML_Directory_Pruner is a SAX2 filter for restricting the output of the XML::Directory::SAX handler.

=cut

package XML::Filter::XML_Directory_Pruner;
use strict;

use Exporter;
use XML::SAX::Base;

$XML::Filter::XML_Directory_Pruner::VERSION   = '1.1';
@XML::Filter::XML_Directory_Pruner::ISA       = qw (Exporter XML::SAX::Base);
@XML::Filter::XML_Directory_Pruner::EXPORT    = qw ();
@XML::Filter::XML_Directory_Pruner::EXPORT_OK = qw ();

=head1 OBJECT METHODS

=head2 $pkg = __PACKAGE__->new()

Inherits from I<XML::SAX::Base>

=head2 $pkg->include(%args)

Include *only* that files that match either the starting or ending pattern.

Valid arguments are 

=over

=item *

B<include>

Array ref.

=item *

B<matching>

String. Regular expression.

I<note that when this expression is compared, leaning toothpicks (e.g. : /$pattern/) are provided for you.>

=item *

B<starting>

Array ref.

=item *

B<ending>

Array ref.

=back

=cut

sub include {
    my $self = shift;
    my $args = { @_ };

    if (ref($args->{'include'})  eq "ARRAY") {
      push (@{$self->{__PACKAGE__.'__include'}},@{$args->{'exclude'}});
    }

    if ($args->{'matching'}) {
      $self->{__PACKAGE__.'__include_matching'} = $args->{'matching'};
    }

    if (ref($args->{'starting'}) eq "ARRAY") {
      push (@{$self->{__PACKAGE__.'__include_starting'}},@{$args->{'starting'}});
    }

    if (ref($args->{'ending'}) eq "ARRAY") {
	push (@{$self->{__PACKAGE__.'__include_ending'}},@{$args->{'ending'}});
    }

    return 1;
}

=head2 $pkg->exclude(%args)

Exclude files with a particular name or pattern from being included in the directory listing.

Valid arguments are

=over

=item *

B<exclude>

Array ref.

=item *

B<matching>

String. Regular expression.

I<note that when this expression is compared, leaning toothpicks (e.g. : /$pattern/) are provided for you.>

=item *

B<starting>

Array ref.

=item *

B<ending>

Array ref.

=item * 

B<directories>

Boolean. Default is false.

B<files>

Boolean. Default is false.

=back

=cut

sub exclude {
    my $self = shift;
    my $args  = { @_ };

    if (ref($args->{'exclude'})  eq "ARRAY") {
      push (@{$self->{__PACKAGE__.'__exclude'}},@{$args->{'exclude'}});
    }

    if ($args->{'matching'}) {
      $self->{__PACKAGE__.'__exclude_matching'} = $args->{'matching'};
    }

    if (ref($args->{'starting'}) eq "ARRAY") {
      push (@{$self->{__PACKAGE__.'__exclude_starting'}},@{$args->{'starting'}});
    }

    if (ref($args->{'ending'})   eq "ARRAY") {
      push (@{$self->{__PACKAGE__.'__exclude_ending'}},@{$args->{'ending'}});
    }
    
    $self->{__PACKAGE__.'__exclude_subdirs'} = $args->{'directories'};
    $self->{__PACKAGE__.'__exclude_files'}   = $args->{'files'};
    return 1;
}

=head2 $pkg->ima($what)

=cut

sub ima {
  my $self = shift;
  my $what = shift;

  if ($what) {
    $self->{__PACKAGE__.'__ima'} = $what;
  }

  return $self->{__PACKAGE__.'__ima'};
}

=head2 $pkg->current_level()

Read-only.

=cut

sub current_level {
  my $self = shift;
  return $self->{__PACKAGE__.'__level'};
}

=head2 $pkg->skip_level()

=cut

sub skip_level {
  return $_[0]->{__PACKAGE__.'__skip'};
}

=head2 $pkg->debug($debug)

=cut

sub debug {
  my $self = shift;
  my $debug = shift;

  if (defined($debug)) {
    $self->{__PACKAGE__.'__debug'} = ($debug) ? 1 : 0;
  }

  return $self->{__PACKAGE__.'__debug'};
}

=head1 PRIVATE METHODS

=head2 $pkg->start_element($data)

=cut

sub start_element {
  my $self = shift;
  my $data = shift;

  $self->on_enter_start_element($data);
  $self->compare($data);

  unless ($self->{__PACKAGE__.'__skip'}) {
    $self->{__PACKAGE__.'__last'} = $data->{'Name'};
    $self->SUPER::start_element($data);
  }

  return 1;
}

sub on_enter_start_element {
  my $self = shift;
  my $data = shift;

  $self->{__PACKAGE__.'__level'} ++;

  if ($self->debug()) {
    map { print STDERR " "; } (0..$self->current_level);
    print STDERR "[".$self->current_level."] $data->{Name} : ";
    # Because sometimes auto-vivification
    # is not what you want.
    if (exists($data->{Attributes}->{'{}same'})) {
      print STDERR $data->{Attributes}->{'{}name'}->{Value};
    }

    print STDERR "\n";
  }

  return 1;
}

=head2 $pkg->end_element($data)

=cut

sub end_element {
  my $self = shift;
  my $data = shift;

  unless ($self->{__PACKAGE__.'__skip'}) {
    $self->SUPER::end_element($data);
  }

  $self->on_exit_end_element();
  return 1;
}

=head2 $pkg->_on_exit_end_element()

=cut

sub on_exit_end_element {
  my $self = shift;

  if ($self->{__PACKAGE__.'__skip'} == $self->{__PACKAGE__.'__level'}) {
    $self->{__PACKAGE__.'__skip'} = 0;
  }

  $self->{__PACKAGE__.'__level'} --;
  return 1;
}

=head2 $pkg->characters($data)

=cut

sub characters {
  my $self = shift;
  my $data = shift;

  unless ($self->{__PACKAGE__.'__skip'}) {
    $self->SUPER::characters($data);
  }
  
  return 1;
}

=head2 $pkg->compare(\%data)

=cut

sub compare {
  my $self = shift;
  my $data = shift;

  if (($data->{'Name'} =~ /^(file|directory)$/) && (! $self->{__PACKAGE__.'__skip'})) {
    $self->{__PACKAGE__.'__ima'} = $1;
    $self->_compare($data->{Attributes}->{'{}name'}->{Value});
  }

  return 1;
}

=head2 $pkg->_compare($data)

=cut

sub _compare {
  my $self = shift;
  my $data = shift;

  my $ok = 1;

  # Note the check on __level. We have to do
  # this, so that filtering the output for
  # /foo/bar won't fail with :
  #
  # 101 ->./dir-machine
  # 1 dirtree
  #  2 head
  #   3 path
  #   3 details
  #   3 depth
  # Comparing 'bar' (directory)...failed directory test...'0' (2)

  if ($self->{__PACKAGE__.'__level'} == 2) { return 1; }

  # Include subdirectories?

  if (($ok) && ($self->{__PACKAGE__.'__ima'} eq "directory" && $self->{__PACKAGE__.'__exclude_subdirs'})) {
    $ok = 0;
  }

  if (($ok) && ($self->{__PACKAGE__.'__ima'} eq "file" && $self->{__PACKAGE__.'__exclude_files'})) {
    $ok = 0;
  }

  #

  if (($ok) && ($self->{__PACKAGE__.'__include_matching'})) {
    my $pattern = $self->{__PACKAGE__.'__include_matching'};
    $ok = ($data =~ /$pattern/) ? 1 : 0;
  }

  if (($ok) && (ref($self->{__PACKAGE__.'__include'}) eq "ARRAY")) {
    foreach my $match (@{$self->{__PACKAGE__.'__include'}}) {
      $ok = ($data =~ /^($match)$/) ? 0 : 1;
      last if (! $ok);
    }
  }

  if (($ok) && (ref($self->{__PACKAGE__.'__include_starting'}) eq "ARRAY")) {
    foreach my $match (@{$self->{__PACKAGE__.'__include_starting'}}) {
      $ok = ($data =~ /^($match)(.*)$/) ? 1 : 0;
      last if (! $ok);
    }
  }

  if (($ok) && (ref($self->{__PACKAGE__.'__include_ending'}) eq "ARRAY")) {
    foreach my $match (@{$self->{__PACKAGE__.'__include_ending'}}) {
      $ok = ($data =~ /^(.*)($match)$/) ? 1 : 0;
      last if (! $ok);
    }
  }

  #

  if (($ok) && ($self->{__PACKAGE__.'__exclude_matching'})) {
    my $pattern = $self->{__PACKAGE__.'__exclude_matching'};
    $ok = ($data =~ /$pattern/) ? 0 : 1;
  }

  if (($ok) && (ref($self->{__PACKAGE__.'__exclude'}) eq "ARRAY")) {
    foreach my $match (@{$self->{__PACKAGE__.'__exclude'}}) {
      $ok = ($data =~ /^($match)$/) ? 0 : 1;
      last if (! $ok);
    }
  }

  if (($ok) && (ref($self->{__PACKAGE__.'__exclude_starting'}) eq "ARRAY")) {
    foreach my $match (@{$self->{__PACKAGE__.'__exclude_starting'}}) {
      $ok = ($data =~ /^($match)(.*)$/) ? 0 : 1;
      last if (! $ok);
    }
  }

  if (($ok) && (ref($self->{__PACKAGE__.'__exclude_ending'}) eq "ARRAY")) {
    foreach my $match (@{$self->{__PACKAGE__.'__exclude_ending'}}) {
      $ok = ($data =~ /^(.*)($match)$/) ? 0 : 1;
      last if (! $ok);
    }
  }

  if (! $ok) {
    if ($self->debug()) {
      print STDERR "SKIPPING '$data' at $self->{__PACKAGE__.'__level'}\n";
    }

    $self->{__PACKAGE__.'__skip'} = $self->{__PACKAGE__.'__level'};
  }

  return 1;
}


=head1 VERSION

1.1

=head1 DATE

June 30, 2002

=head1 AUTHOR

Aaron Straup Cope

=head1 TO DO

=over

=item *

Allow for inclusion/exclusion based on mime-type

=back

=head1 SEE ALSO

L<XML::Directory::SAX>

L<XML::SAX::Base>

=head1 LICENSE

Copyright (c) 2002, Aaron Straup Cope. All Rights Reserved.

This is free software, you may use it and distribute it under the same terms as Perl itself.

=cut

return 1;

}
