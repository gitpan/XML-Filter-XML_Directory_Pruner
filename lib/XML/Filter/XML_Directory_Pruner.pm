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

$XML::Filter::XML_Directory_Pruner::VERSION   = '1.0';
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
      push (@{$self->{'__include'}},@{$args->{'exclude'}});
    }

    if ($args->{'matching'}) {
      $self->{'__include_matching'} = $args->{'matching'};
    }

    if (ref($args->{'starting'}) eq "ARRAY") {
      push (@{$self->{'__include_starting'}},@{$args->{'starting'}});
    }

    if (ref($args->{'ending'}) eq "ARRAY") {
	push (@{$self->{'__include_ending'}},@{$args->{'ending'}});
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
      push (@{$self->{'__exclude'}},@{$args->{'exclude'}});
    }

    if ($args->{'matching'}) {
      $self->{'__exclude_matching'} = $args->{'matching'};
    }

    if (ref($args->{'starting'}) eq "ARRAY") {
      push (@{$self->{'__exclude_starting'}},@{$args->{'starting'}});
    }

    if (ref($args->{'ending'})   eq "ARRAY") {
      push (@{$self->{'__exclude_ending'}},@{$args->{'ending'}});
    }
    
    $self->{'__exclude_subdirs'} = $args->{'directories'};
    $self->{'__exclude_files'}   = $args->{'files'};
    return 1;
}

=head1 PRIVATE METHODS

=head2 $pkg->start_element($data)

=cut

sub start_element {
  my $self = shift;
  my $data = shift;

  $self->{'__level'} ++;

  if (($data->{'Name'} =~ /^(file|directory)$/) && (! $self->{'__skip'})) {
    $self->{'__ima'} = $1;
    $self->_compare($data->{Attributes}->{'{}name'}->{Value});
  }

  unless ($self->{'__skip'}) {
    $self->{'__last'} = $data->{'Name'};
    $self->SUPER::start_element($data);
  }

  return 1;
}

=head2 $pkg->end_element($data)

=cut

sub end_element {
  my $self = shift;
  my $data = shift;

  unless ($self->{'__skip'}) {
    $self->SUPER::end_element($data);
  }

  if ($self->{'__skip'} == $self->{'__level'}) {
    $self->{'__skip'} = 0;
  }

  $self->{'__level'} --;
  return 1;
}

=head2 $pkg->characters($data)

=cut

sub characters {
  my $self = shift;
  my $data = shift;

  unless ($self->{'__skip'}) {
    $self->SUPER::characters($data);
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

  if ($self->{'__level'} == 2) { return 1; }

  # Include subdirectories?

  if (($ok) && ($self->{'__ima'} eq "directory" && $self->{'__exclude_subdirs'})) {
    $ok = 0;
  }

  if (($ok) && ($self->{'__ima'} eq "file" && $self->{'__exclude_files'})) {
    $ok = 0;
  }

  #

  if (($ok) && ($self->{'__include_matching'})) {
    my $pattern = $self->{'__include_matching'};
    $ok = ($data =~ /$pattern/) ? 1 : 0;
  }

  if (($ok) && (ref($self->{'__include'}) eq "ARRAY")) {
    foreach my $match (@{$self->{'__include'}}) {
      $ok = ($data =~ /^($match)$/) ? 0 : 1;
      last if (! $ok);
    }
  }

  if (($ok) && (ref($self->{'__include_starting'}) eq "ARRAY")) {
    foreach my $match (@{$self->{'__include_starting'}}) {
      $ok = ($data =~ /^($match)(.*)$/) ? 1 : 0;
      last if (! $ok);
    }
  }

  if (($ok) && (ref($self->{'__include_ending'}) eq "ARRAY")) {
    foreach my $match (@{$self->{'__include_ending'}}) {
      $ok = ($data =~ /^(.*)($match)$/) ? 1 : 0;
      last if (! $ok);
    }
  }

  #

  if (($ok) && ($self->{'__exclude_matching'})) {
    my $pattern = $self->{'__exclude_matching'};
    $ok = ($data =~ /$pattern/) ? 0 : 1;
  }

  if (($ok) && (ref($self->{'__exclude'}) eq "ARRAY")) {
    foreach my $match (@{$self->{'__exclude'}}) {
      $ok = ($data =~ /^($match)$/) ? 0 : 1;
      last if (! $ok);
    }
  }

  if (($ok) && (ref($self->{'__exclude_starting'}) eq "ARRAY")) {
    foreach my $match (@{$self->{'__exclude_starting'}}) {
      $ok = ($data =~ /^($match)(.*)$/) ? 0 : 1;
      last if (! $ok);
    }
  }

  if (($ok) && (ref($self->{'__exclude_ending'}) eq "ARRAY")) {
    foreach my $match (@{$self->{'__exclude_ending'}}) {
      $ok = ($data =~ /^(.*)($match)$/) ? 0 : 1;
      last if (! $ok);
    }
  }

  if (! $ok) {
    $self->{'__skip'} = $self->{'__level'};
  }

  return 1;
}

=head1 VERSION

1.0

=head1 DATE

May 04, 2002

=head1 AUTHOR

Aaron Straup Cope

=head1 SEE ALSO

L<XML::Directory>

L<XML::SAX::Base>

=head1 LICENSE

Copyright (c) 2002, Aaron Straup Cope. All Rights Reserved.

This is free software, you may use it and distribute it under the same terms as Perl itself.

=cut

return 1;

}
