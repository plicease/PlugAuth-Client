package SimpleAuth::Client;

use strict;
use warnings;
use v5.10;
use Log::Log4perl qw(:easy);
use Clustericious::Client;

# ABSTRACT: SimpleAuth Client
our $VERSION = '0.10'; # VERSION


route welcome      => 'GET', '/';


route auth         => 'GET', '/auth';


route_doc authz    => "user action resource";
sub authz
{
  my($self, $user, $action, $resource) = @_;

  my $url = Mojo::URL->new( $self->server_url );

  $resource = "/$resource" unless $resource =~ m{^/};
  
  $url->path("/authz/user/$user/$action$resource");

  $self->_doit('GET', $url);
}


route user         => 'GET', '/user';


route create_user => 'POST', '/user', \("--user username --password password");
route_args create_user => [
  { name => 'user',     type => '=s', required => 1 },
  { name => 'password', type => '=s', required => 1 },
];


route delete_user  => 'DELETE',  '/user', \("user");


route groups       => 'GET', '/groups', \("user");


route_doc change_password => 'username password';
sub change_password
{
  my($self, $user, $password) = @_;
  my $url = Mojo::URL->new( $self->server_url );
  $url->path("/user/$user");
  $self->_doit('POST', $url, { password => $password });
}


route group        => 'GET', '/group';


route users        => 'GET', '/users', \("group");


route create_group => 'POST', '/group', \("--group group --users user1,user2,...");
route_args create_group => [
  { name => 'group', type => '=s', required => 1 },
  { name => 'users', type => '=s', required => 1 },
];


route_doc 'update_group' => 'group --users user1,user2,...';
route_args update_group => [
  { name => 'users', type => '=s', required => 1 },
];
sub update_group
{
  my $self = shift;
  my $group = shift;
  my $args = ref($_[0]) eq 'HASH' ? $_[0] : {@_}; 

  LOGDIE "group needed for update"
    unless $group;

  my $url = Mojo::URL->new( $self->server_url );
  $url->path("/group/$group");

  TRACE("updating $group ", $url->to_string);

  $self->_doit('POST', $url, { users => $args->{users} // $args->{'--users'} });
}


route delete_group => 'DELETE', '/group', \("group");


route_doc 'grant'  => 'group action resource';

sub grant
{
  my($self, $group, $action, $resource) = @_;

  LOGDIE "group, action and resource needed for grant"
    unless $group && $action && $resource;

  $resource =~ s/^\///;

  my $url = Mojo::URL->new( $self->server_url );
  $url->path("/grant/$group/$action/$resource");

  $self->_doit('POST', $url);
}


route actions      => 'GET', '/actions';


route host_tag     => 'GET', '/host', \("host tag");


route resources    => 'GET', '/authz/resources', \("user action resource_regex");


route_doc action_resources => "user";
sub action_resources
{
  my($self, $user) = @_;
  my %table;
  foreach my $action (@{ $self->actions })
  {
    my $resources = $self->resources($user, $action, '/');
    $table{$action} = $resources if @$resources > 0;
  }
  \%table;
}

1;



=pod

=head1 NAME

SimpleAuth::Client - SimpleAuth Client

=head1 VERSION

version 0.10

=head1 SYNOPSIS

In a perl program :

 my $r = SimpleAuth::Client->new;

 # Check auth server status and version
 my $check = $r->status;
 my $version = $r->version;

 # Authenticate user "alice", pw "sesame"
 $r->login(user => "alice", password => "sesame");
 if ($r->auth) {
    print "authentication succeeded\n";
 } else {
    print "authentication failed\n";
 }

 # Authorize "alice" to "POST" to "/board"
 if ($r->authz("alice","POST","board")) {
     print "authorization succeeded\n";
 } else {
     print "authorization failed\n";
 }

=head1 DESCRIPTION

This module provides a perl front-end to the SimpleAuth API.

=head1 METHODS

=head2 $client-E<gt>auth

Returns true if the SimpleAuth server can authenticate the user.  
Username and passwords can be specified with the login method or
via the application's configuration file, see L<Clustericious::Client>
for details.

=head2 $client-E<gt>authz($user $action, $resource)

Returns true if the given user ($user) is authorized to perform the
given action ($action) on the given resource ($resource).

=head2 $client-E<gt>user

Returns a list reference containing all usernames.

=head2 $client-E<gt>create_user( \%args )

Create a user with the given username and password.

=over 4

=item * username

The new user's username

=item * password

The new user's password

=back

=head2 $client-E<gt>delete_user( $username )

Delete the user with the given username.

=head2 $client-E<gt>groups($user)

Returns a list reference containing the groups that the given user ($user)
belongs to.

=head2 $client-E<gt>change_password($user, $password)

Change the password of the given user ($user) to a new password ($password).

=head2 $client-E<gt>group

Returns a list reference containing all group names.

=head2 $client-E<gt>users($group)

Returns the list of users belonging to the given group ($group).

=head2 $client-E<gt>create_group( \%args )

Create a group.

=over 4

=item * group

The name of the new group

=item * users

Comma separated list (as a string) of the users that
should initially belong to this group.

=back

=head2 $client-E<gt>update_group( $group, '--users' => $users )

Update the given group ($group) replacing the existing list with
the new list ($users), wihch is a comma separated list as a string.

=head2 $client-E<gt>delete_group( $group )

Delete the given group ($group).

=head2 $client-E<gt>grant( $user, $action, $resource )

Grants the given user ($user) the authorization to perform the given
action ($action) on the given resource ($resource).

=head2 $client-E<gt>actions

Returns a list reference containing the actions that the SimpleAuth server
knows about.

=head2 $client-E<gt>host_tag($ip_address, $tag)

Returns true if the host specified by the given IP address ($ip_address)
has the given host tag ($tag).

=head2 $client-E<gt>resources( $user, $action, $resource_regex )

Returns a list reference containing the resources that match the regex
provided ($resource_regex) that the given user ($user) can perform the
given action ($action).  To see all the resources that the user can
perform the given action against, pass in '.*' as the regex.

=head2 $client-E<gt>action_resources( $user )

Returns a hash reference of all actions and resources that the given
user ($user) can perform.  The keys in the returned hash are the 
actions and the values are list references containing the resources
where those actions can be performed by the user.

=head1 COMMAND LINE

The SimpleAuth API can also be interfaced on the command line
using the simpleauthclient command:

  # Find all URLs containing /xyz, alice has permission to GET
  simpleauthclient resources alice GET /xyz

  # Check which resources containing the word "ball" are available
  # for charliebrown to perform the "kick" action :
  simpleauthclient resources charliebrown kick ball

  # Check if a given host has the tag "trusted"
  simpleauthclient host_tag 127.0.0.1 trusted

  # List of users
  simpleauthclient user

  # List of groups
  simpleauthclient group

  # List of users belonging to peanuts group
  simpleauthclient users peanuts

=head1 SEE ALSO

L<Clustericious::Client>, L<SimpleAuth>

=head1 AUTHOR

Graham Ollis <gollis@sesda2.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by NASA GSFC.  No
license is granted to other entities.

=cut


__END__

