#
# Lgrp.pm provides procedural and object-oriented interface to the Solaris
# liblgrp(3LIB) library.
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms
# of the Common Development and Distribution License
# (the "License").  You may not use this file except
# in compliance with the License.
#
# You can obtain a copy of the license at
# http://www.opensolaris.org/os/licensing.
# A copy of the license file is included with this module.
# See the License for the specific language governing
# permissions and limitations under the License.
#
# When distributing Covered Code, include this CDDL
# HEADER in each file and include the License file at
# LICENSE. If applicable,
# add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your
# own identifying information: Portions Copyright [yyyy]
# [name of copyright owner]
#
# CDDL HEADER END
#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
#ident	"@(#)Lgrp.pm	1.1	05/08/05"
#

use strict;
use warnings;
use Carp;

package Solaris::Lgrp;

our $VERSION = '0.1.1';
use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

require Exporter;

our @ISA = qw(Exporter);

our (@EXPORT_OK, %EXPORT_TAGS);

# Things to export
my @lgrp_constants = qw(LGRP_AFF_NONE LGRP_AFF_STRONG LGRP_AFF_WEAK
			LGRP_CONTENT_DIRECT LGRP_CONTENT_HIERARCHY
			LGRP_MEM_SZ_FREE LGRP_MEM_SZ_INSTALLED LGRP_VER_CURRENT
			LGRP_VER_NONE LGRP_VIEW_CALLER
			LGRP_VIEW_OS LGRP_NONE
			LGRP_RSRC_CPU LGRP_RSRC_MEM
			LGRP_CONTENT_ALL LGRP_LAT_CPU_TO_MEM
);

my @proc_constants = qw(P_PID P_LWPID P_MYID);

my @constants = (@lgrp_constants, @proc_constants);

my @functions = qw(lgrp_affinity_get lgrp_affinity_set
		   lgrp_children lgrp_cookie_stale lgrp_cpus lgrp_fini
		   lgrp_home lgrp_init lgrp_latency lgrp_latency_cookie
		   lgrp_mem_size lgrp_nlgrps lgrp_parents
		   lgrp_root lgrp_version lgrp_view lgrp_resources
		   lgrp_isleaf lgrp_lgrps lgrp_leaves);

my @all = (@constants, @functions);

# Define symbolic names for various subsets of export lists
%EXPORT_TAGS = ('CONSTANTS' => \@constants,
		'LGRP_CONSTANTS' => \@lgrp_constants,
		'PROC_CONSTANTS' => \@proc_constants,
		'FUNCTIONS' => \@functions,
		'ALL' => \@all);

# Define things that are ok ot export.
@EXPORT_OK = ( @{ $EXPORT_TAGS{'ALL'} } );


# lgrp_isleaf($cookie, $lgrp)
# Returns T if lgrp is leaf, F otherwise.
sub lgrp_isleaf($$) { !lgrp_children(shift, shift); }

# lgrp_lgrps($cookie, [$lgrp])
# Returns: list of lgrps in a subtree starting from $root.
# 	   If $root is not specified, use lgrp_root.
# 	   undef on failure.
sub lgrp_lgrps($;$)
{
    my $cookie = shift;
    my $root = shift;
    $root = lgrp_root($cookie) unless defined $root;
    return unless defined $root;
    my @children = lgrp_children($cookie, $root);
    my @result;

    # Concatenate root with subtrees for every children.
    # Every subtree is obtained by calling lgrp_lgrps recursively with each of
    # the children as the argument.
    @result = @children ?
      ($root, map {lgrp_lgrps($cookie, $_)} @children) :
	($root);
    return (wantarray ? @result : scalar @result);
}

# lgrp_leaves($cookie, [$root])
# Return list of leaves in the hierarchy starting from $root.
# 	 If $root is not specified, use lgrp_root.
# 	 undef on failure.
sub lgrp_leaves($;$)
{
    my $cookie = shift;
    my $root = shift;
    $root = lgrp_root($cookie) unless defined $root;
    return unless defined $root;
    my @result = grep { lgrp_isleaf($cookie, $_) } lgrp_lgrps($cookie, $root);
    return (wantarray ? @result : scalar @result);
}

######################################################################
# Object-Oriented interface.
######################################################################

##############################################################
# cookie: extract cookie from the argument.
# If the argument is scalar, it is the cookie itself, otherwise it is the
# reference to the object and the cookie value is in $self->{COOKIE}.
##
sub cookie($)
{
    my $self = shift;
    (ref $self) ? $self->{COOKIE} : $self;
}

############################################################
# new: The object constructor
##
sub new($;$)
{
    my $class = shift;
    my ($self, $view);
    $view = shift;
    $self->{COOKIE} = ($view ? lgrp_init($view) : lgrp_init()) or
	croak("lgrp_init: $!\n"), return;
    bless($self, $class) if defined($class);
    bless($self) unless defined($class);
    return $self;
}

#############################################################
# DESTROY: the object destructor.
##
sub DESTROY { lgrp_fini(cookie(shift)); }

#############################################################
# _usage(): print error message and terminate the program.
##
sub _usage($)
{
    my $msg = shift;

    Carp::croak "Usage: Solaris::Lgrp::$msg";
}

############################################################
# Wrapper methods.
##
sub stale($) 		{ lgrp_cookie_stale(cookie(shift)) }
sub view($) 		{ lgrp_view(cookie(shift)) }
sub root($)		{ lgrp_root(cookie(shift)) }
sub nlgrps($) 		{ lgrp_nlgrps(cookie(shift)) }
sub lgrps($;$)		{ lgrp_lgrps(cookie(shift), shift) }
sub leaves($;$)		{ lgrp_leaves(cookie(shift), shift) }
sub version($$)		{ shift; lgrp_version(shift || 0) }

sub children($$)
{
    scalar @_ == 2 or _usage "children(class, lgrp)";
    lgrp_children (cookie(shift), shift);
}

sub parents($$)
{
    scalar @_ == 2 or _usage "parents(class, lgrp)";
    lgrp_parents (cookie(shift), shift);
}

sub mem_size($$$$)
{
    scalar @_ == 4 or _usage "mem_size(class, lgrp, type, content)";
    lgrp_mem_size(cookie(shift), shift, shift, shift);
}

sub cpus($$$)
{
    scalar @_ == 3 or _usage "cpus(class, lgrp, content)";
    lgrp_cpus(cookie(shift), shift, shift);
}

sub isleaf($$)
{
    scalar @_ == 2 or _usage "isleaf(class, lgrp)";
    lgrp_isleaf(cookie(shift), shift);
}

sub resources($$$)
{
    scalar @_ == 3 or _usage "resources(class, lgrp, resource)";
    lgrp_resources(cookie(shift), shift, shift);
}

sub latency($$$)
{
    scalar @_ == 3 or _usage "latency(class, from, to)";
    lgrp_latency_cookie(cookie(shift), shift, shift);
}

# Methods that do not require cookie
sub home($$$)
{
    scalar @_ == 3 or _usage "home(class, idtype, id)";
    shift;
    lgrp_home(shift, shift);
}

sub affinity_get($$$$)
{
    scalar @_ == 4 or _usage "affinity_get(class, idtype, id, lgrp)";
    shift;
    lgrp_affinity_get(shift, shift, shift);
}

sub affinity_set($$$$$)
{
    scalar @_ == 5 or _usage "affinity_set(class, idtype, id, lgrp, affinity)";
    shift;
    lgrp_affinity_set(shift, shift, shift, shift);
}

1;

__END__

=head1 NAME

Solaris::Lgrp - Perl interface to Solaris liblgrp(3LIB) library.

=head1 SYNOPSIS

All functions return B<undef> or empty list on failure. The B<$!> variable
contains the system errno value.

  use Solaris::Lgrp qw(:ALL);

  # initialize lgroup interface
  my $cookie = lgrp_init(LGRP_VIEW_OS | LGRP_VIEW_CALLER);
  my $l = Solaris::Lgrp->new(LGRP_VIEW_OS | LGRP_VIEW_CALLER);

  my $version = lgrp_version(LGRP_VER_CURRENT | LGRP_VER_NONE);
  $version = $l->version(LGRP_VER_CURRENT | LGRP_VER_NONE);

  $home = lgrp_home(P_PID, P_MYID);
  $home = l->home(P_PID, P_MYID);

  lgrp_affinity_set(P_PID, $pid, $lgrp,
	LGRP_AFF_STRONG | LGRP_AFF_WEAK | LGRP_AFF_NONE);
  $l->affinity_set(P_PID, $pid, $lgrp,
	LGRP_AFF_STRONG | LGRP_AFF_WEAK | LGRP_AFF_NONE);

  my $affinity = lgrp_affinity_get(P_PID, $pid, $lgrp);
  $affinity = $l->affinity_get(P_PID, $pid, $lgrp);

  my $nlgrps = lgrp_nlgrps($cookie);
  $nlgrps = $l->nlgrps();

  my $root = lgrp_root($cookie);
  $root = l->root();

  $latency = lgrp_latency($lgrp1, $lgrp2);
  $latency = $l->latency($lgrp1, $lgrp2);

  my @children = lgrp_children($cookie, $lgrp);
  @children = l->children($lgrp);

  my @parents = lgrp_parents($cookie, $lgrp);
  @parents = l->parents($lgrp);

  my @lgrps = lgrp_lgrps($cookie);
  @lgrps = l->lgrps();

  @lgrps = lgrp_lgrps($cookie, $lgrp);
  @lgrps = l->lgrps($lgrp);

  my @leaves = lgrp_leaves($cookie);
  @leaves = l->leaves();

  my $is_leaf = lgrp_isleaf($cookie, $lgrp);
  $is_leaf = $l->is_leaf($lgrp);

  my @cpus = lgrp_cpus($cookie, $lgrp,
	LGRP_CONTENT_HIERARCHY | LGRP_CONTENT_DIRECT);
  @cpus = l->cpus($lgrp, LGRP_CONTENT_HIERARCHY | LGRP_CONTENT_DIRECT);

  my $memsize = lgrp_mem_size($cookie, $lgrp,
	LGRP_MEM_SZ_INSTALLED | LGRP_MEM_SZ_FREE,
	LGRP_CONTENT_HIERARCHY | LGRP_CONTENT_DIRECT);
  $memsize = l->mem_size($lgrp,
	LGRP_MEM_SZ_INSTALLED | LGRP_MEM_SZ_FREE,
	LGRP_CONTENT_HIERARCHY | LGRP_CONTENT_DIRECT);

  my $is_stale = lgrp_cookie_stale($cookie);
  $stale = l->stale();

  lgrp_fini($cookie);

The following is available for API version greater than 1:

  my @lgrps = lgrp_resources($cookie, $lgrp, LGRP_RSRC_CPU);

  # Get latencies from cookie
  $latency = lgrp_latency_cookie($cookie, $from, $to);

=head1 DESCRIPTION

The functions in this module traverse the lgroup (locality group) hierarchy,
discover its contents, and set a thread's affinity for an lgroup. A locality
group represents the set of CPU-like and memory-like hardware devices that are
at most some locality apart from each other. The module is a Perl interface to
the C<liblgrp(3LIB)> library, so its usage is very close to the liblgrp calls.

The module gives access to various constants and functions defined in
C<sys/lgrp_sys.h> header file. It provides both the procedural and object
interface to the library. The procedural interface requires (in most cases)
passing a transparent cookie around. The object interface hides all the cookie
manipulations from the user.

Functions returning scalar value indicate error by returning B<undef>. The
caller may examine the B<$!> variable to get the C<errno> value.

Functions returning list value return the number of elements in the list when
called in scalar context. In case of error the empty list is return in the array
context and B<undef> is returned in the scalar context.

=head2 EXPORTS

By default nothing is exported from this module. The following tags can be used
to selectively import constants and functions defined in this module:

=over

=item :LGRP_CONSTANTS

LGRP_AFF_NONE, LGRP_AFF_STRONG, LGRP_AFF_WEAK, LGRP_CONTENT_DIRECT,
LGRP_CONTENT_HIERARCHY, LGRP_MEM_SZ_FREE, LGRP_MEM_SZ_INSTALLED,
LGRP_VER_CURRENT, LGRP_VER_NONE, LGRP_VIEW_CALLER, LGRP_VIEW_OS,
LGRP_NONE, LGRP_RSRC_CPU, LGRP_RSRC_MEM, LGRP_CONTENT_ALL,
LGRP_LAT_CPU_TO_MEM.

=item :PROC_CONSTANTS

P_PID, P_LWPID P_MYID

=item :CONSTANTS

:LGRP_CONSTANTS, :PROC_CONSTANTS

=item :FUNCTIONS

lgrp_affinity_get(), lgrp_affinity_set(), lgrp_children(), lgrp_cookie_stale(),
lgrp_cpus(), lgrp_fini(), lgrp_home(), lgrp_init(), lgrp_latency(),
lgrp_latency_cookie(), lgrp_mem_size(), lgrp_nlgrps(), lgrp_parents(),
lgrp_root(), lgrp_version(), lgrp_view(), lgrp_resources(),
lgrp_lgrps(), lgrp_leaves(), lgrp_isleaf(), lgrp_lgrps(), lgrp_leaves().

=item :ALL

:CONSTANTS, :FUNCTIONS

=back

=head2 METHODS

new(),
cookie(),
stale(),
view(),
root(),
children(),
parents(),
nlgrps(),
mem_size(),
cpus(),
isleaf(),
resources(),
version(),
home(),
affinity_get(),
affinity_set(),
lgrps(),
leaves(),
latency().


=head2 Difference in the API versions

Currently there are two versions of the LGRP API which are slightly
incompatible. The exact version which was used to compile a module is available
through B<lgrp_version> function.

Version 2 of the lgrpp_user API introduced some new constants and functions:

=over

=item C<LGRP_RSRC_CPU> constant

=item C<LGRP_RSRC_MEM> constant

=item C<LGRP_CONTENT_ALL> constant

=item C<LGRP_LAT_CPU_TO_MEM> constant

=item C<lgrp_resources()> function

=item C<lgrp_latency_cookie()> function

=back

The C<LGRP_RSRC_CPU> and C<LGRP_RSRC_MEM> are not defined for version 1. The
L<lgrp_resources()> function is defined for version 1 but always returns empty
list. The L<lgrp_latency_cookie()> function is an alias for lgrp_latency for
version 1.

=head2 Exportable constants

The constants are exported with B<:CONSTANTS> or B<:ALL> tags:

  use LGRP::User ':ALL';
or
  use LGRP::User ':CONSTANTS';

The following constants are available for use in Perl programs:

  LGRP_NONE

  LGRP_VER_CURRENT
  LGRP_VER_NONE

  LGRP_VIEW_CALLER
  LGRP_VIEW_OS

  LGRP_AFF_NONE
  LGRP_AFF_STRONG
  LGRP_AFF_WEAK

  LGRP_CONTENT_DIRECT
  LGRP_CONTENT_HIERARCHY

  LGRP_MEM_SZ_FREE
  LGRP_MEM_SZ_INSTALLED

  LGRP_RSRC_CPU (1)
  LGRP_RSRC_MEM (1)
  LGRP_CONTENT_ALL (1)
  LGRP_LAT_CPU_TO_MEM(1)

  P_PID
  P_LWPID
  P_MYID

(1) Available for versions API greater than 1.

=head2 Error values

The functions in this module return B<undef> or an empty list when an underlying
library function fails. The B<$!> is set to provide more information values for
the error. The following error codes are possible:

=over

=item EINVAL

The value supplied is not valid.

=item ENOMEM

There was not enough system memory to complete an operation.

=item ESRCH

The specified  process or thread was not found.

=item EPERM

The effective user of the calling process does not have appropriate privileges,
and its real or effective user ID does not match the real or effective user ID
of one of the threads.

=back

=head2 Exportable functions

The detailed description of each function follows.

=over

=item lgrp_init([LGRP_VIEW_CALLER | LGRP_VIEW_OS])

The function initializes the lgroup interface and takes a snapshot of the lgroup
hierarchy with the given view.  If the given view is C<LGRP_VIEW_CALLER> (which
is the default), the snapshot contains only the resources that are available to
the caller (for example, with respect to processor sets). When the view is
C<LGRP_VIEW_OS>, the snapshot contains what is available to the operating
system. If no view is specified, C<LGRP_VIEW_OS> is assumed as the default.

Given the view, L<lgrp_init()> returns a cookie representing this snapshot of
the lgroup hierarchy. This cookie should be used with other routines in the
lgroup interface needing the lgroup hierarchy. The L<lgrp_fini()> function
should be called with the cookie when it is no longer needed.

The lgroup hierarchy consists of a root lgroup, which is the maximum bounding
locality group of the system. It contains all the CPU and memory resources of
the machine and can contain other locality groups that contain CPUs and memory
within a smaller locality.

Upon successful completion, L<lgrp_init()> returns a cookie. Otherwise it returns
B<undef> and sets B<$!> to indicate the error.

=item lgrp_fini($cookie)

The function takes a cookie, frees the snapshot of the lgroup hierarchy created
by L<lgrp_init()>, and cleans up anything else set up by L<lgrp_init()>. After
this function is called, any memory allocated and returned by the lgroup
interface might no longer be valid and should not be used.

Upon successful completion, 1 is returned. Otherwise, B<undef> is returned and
B<$!> is set to indicate the error.

=item lgrp_view($cookie)

The function takes a cookie representing the snapshot of the lgroup hierarchy
and returns the snapshot's view of the lgroup hierarchy.

If the given view is C<LGRP_VIEW_CALLER>, the snapshot contains only the
resources that are available to the caller (such as those with respect to
processor sets).  When the view is C<LGRP_VIEW_OS>, the snapshot contains what
is available to the operating system.

Upon succesful completion, the function returns the view for the snapshot of the
lgroup hierarchy represented by the given cookie. Otherwise, B<undef> is
returned and C<$!> is set.

=item lgrp_home($idtype, $id)

Returns the home lgroup for the given process or thread. A thread can have an
affinity for an lgroup in the system such that the thread will tend to be
scheduled to run on that lgroup and allocate memory from there whenever
possible. The lgroup with the strongest affinity that the thread can run on is
known as the "home lgroup" of the thread. If the thread has no affinity for any
lgroup that it can run on, the operating system will choose a home for it.

The $idtype argument should be C<P_PID> to specify a process and the C<$id>
argument should be its process id. Otherwise, the idtype argument should be
C<P_LWPID> to specify a thread and the C<$id> argument should be its LWP id. The
value C<P_MYID> can be used for the id argument to specify the current process
or thread.

Upon successful completion, L<lgrp_home()> returns the id of the home lgroup of
the specified process or thread. Otherwise, B<undef> is returned and B<$!> is
set to indicate the error.

=item lgrp_cookie_stale($cookie)

The function takes a cookie representing the snapshot of the lgroup hierarchy
and returns whether it is stale.  The snapshot can become out-of-date for a
number of reasons depending on its view.  If the snapshot was taken with
C<LGRP_VIEW_OS>, changes in the lgroup hierarchy from dynamic reconfiguration,
CPU on/offline, or other conditions can cause the snapshot to become
out-of-date.  A snapshot taken with C<LGRP_VIEW_CALLER> can be affected by the
caller's processor set binding and changes in its processor set itself, as well
as changes in the lgroup hierarchy.

If the snapshot needs to be updated, L<lgrp_fini()> should be called with the
old cookie and L<lgrp_init()> should be called to obtain a new snapshot.

Upon successful completion, the function returns whether the cookie is
stale. Otherwise, it returns B<undef> and sets B<$!> errno to indicate the error.

The L<lgrp_cookie_stale()> function will fail with C<EINVAL> if the cookie is
not valid.

=item lgrp_cpus($cookie, $lgrp, $context)

The function takes a cookie representing a snapshot of the lgroup hierarchy and
returns the list of CPUs in the lgroup specified by $lgrp. The context argument
should be set to one of the following values to specify whether the direct
contents or everything in this lgroup including its children should be returned:

=over

=item LGRP_CONTENT_HIERARCHY

Everything within this hierarchy.

=item LGRP_CONTENT_DIRECT

Directly contained in lgroup.

=back

When called in scalar context, C<lgrp_cpus()> function returns the number of
CPUs, contained in the specified lgroup.

In case of error B<undef> is returned in scalar context and B<$!> is set to
indicate the error. In list context the empty list is returned and B<$!> is set.

=item lgrp_children($cookie, $lgrp)

The function takes a cookie representing a snapshot of the lgroup hierarchy and
returns the list of lgroups that are children of the specified lgroup.

When called in scalar context, C<lgrp_children()> function returns the number of
children lgroups for the specified lgroup.

In case of error B<undef> or empty list is returned and B<$!> is set to indicate
the error.

=item lgrp_parents($cookie, $lgrp)

The function takes a cookie representing a snapshot of the lgroup hierarchy and
returns the list of parent of the specified lgroup.

When called in scalar context, C<lgrp_parents()> function returns the number of
parent lgroups for the specified lgroup.

In case of error B<undef> or empty list is returned and B<$!> is set to indicate
the error.

=item lgrp_nlgrps($cookie)

The function takes a cookie representing a snapshot of the lgroup hierarchy.  It
returns the number of lgroups in the hierarchy where the number is always at
least one.

In case of error B<undef> is returned and B<$!> is set to EINVAL indicatng that 
the cookie is not valid.

=item lgrp_root($cookie)

The function returns the root lgroup $id.  In case of error B<undef> is returned
and B<$!> is set to EINVAL indicatng that the cookie is not valid.

=item lgrp_mem_size($cookie, $lgrp, $type, $content)

The function takes a cookie representing a snapshot of the lgroup hierarchy. The
function returns the memory size of the given lgroup in bytes. The type argument
should be set to one of the following values:

=over

=item LGRP_MEM_SZ_FREE

Free memory.

=item LGRP_MEM_SZ_INSTALLED

Installed memory.

=back

The content argument should be set to one of the following values to specify
whether the direct contents or everything in this lgroup including its children
should be returned:

=over

=item LGRP_CONTENT_HIERARCHY

Everything within this hierarchy.

=item LGRP_CONTENT_DIRECT

Directly contained in lgroup.

=back

The total sizes include all the memory in the lgroup including its children,
while the others reflect only the memory contained directly in the given lgroup.

Upon successful completion, the size in bytes is returned. Otherwise, B<undef>
is returned and B<$!> is set to indicate the error.

=item lgrp_version([VERSION])

The function takes an interface version number, version, as an argument and
returns an lgroup inter- face version. The version argument should be the value
of C<LGRP_VER_CURRENT> bound to the application when it was compiled or
C<LGRP_VER_NONE> to find out the current lgroup interface version on the running
system.

If version is still supported by the implementation, then L<lgrp_version()>
returns the requested version. If C<LGRP_VER_NONE> is returned, the
implementation cannot support the requested version. The application should be
recompiled and might require further changes.

If version is C<LGRP_VER_NONE>, L<lgrp_version()> returns the current version of
the library.

The following example  tests  whether  the  version  of  the
interface used by the caller is supported:


    lgrp_version(LGRP_VER_CURRENT) == LGRP_VER_CURRENT or
    	die("Built with unsupported lgroup interface");


=item lgrp_affinity_set($idtype, $id, $lgrp, $affinity)

The function sets of LWPs specified by the $idtype and $id arguments have for the
given lgroup.

The function sets the affinity that the LWP or set of LWPs specified by $idtype
and $id have for the given lgroup. The lgroup affinity can be set to
C<LGRP_AFF_STRONG>, C<LGRP_AFF_WEAK>, or C<LGRP_AFF_NONE>.

If the $idtype is C<P_PID>, the affinity is retrieved for one of the LWPs in the
process or set for all the LWPs of the process with process id (PID) $id. The
affinity is retrieved or set for the LWP of the current process with LWP id $id
if idtype is C<P_LWPID>.  If $id is C<P_MYID>, then the current LWP or process is
specified.

The operating system uses the lgroup affinities as advice on where to run a
thread and allocate its memory and factors this advice in with other
constraints.  Processor binding and processor sets can restrict which lgroups a
thread can run on, but do not change the lgroup affinities.

Each thread can have an affinity for an lgroup in the system such that the
thread will tend to be scheduled to run on that lgroup and allocate memory from
there whenever possible.  If the thread has affinity for more than one lgroup,
the operating system will try to run the thread and allocate its memory on the
lgroup for which it has the strongest affinity, then the next strongest, and so
on up through some small, system-dependent number of these lgroup affinities.
When multiple lgroups have the same affinity, the order of preference among them
is unspecified and up to the operating system to choose.  The lgroup with the
strongest affinity that the thread can run on is known as its "home lgroup" (see
L<lgrp_home>) and is usually the operating system's first choice of where to run
the thread and allocate its memory.

There are different levels of affinity that can be specified by a thread for a
particuliar lgroup.  The levels of affinity are the following from strongest to
weakest:

=over

=item LGRP_AFF_STRONG

Strong affinity.

=item LGRP_AFF_WEAK

Weak affinity.

=item LGRP_AFF_NONE

No affinity.

=back

The C<LGRP_AFF_STRONG> affinity serves as a hint to the operating system that
the calling thread has a strong affinity for the given lgroup.  If this is the
thread's home lgroup, the operating system will avoid rehoming it to another
lgroup if possible.  However, dynamic reconfiguration, processor offlining,
processor binding, and processor set binding and manipulation are examples of
events that can cause the operating system to change the thread's home lgroup
for which it has a strong affinity.

The C<LGRP_AFF_WEAK> affinity is a hint to the operating system that the calling
thread has a weak affinity for the given lgroup.  If a thread has a weak
affinity for its home lgroup, the operating system interpets this to mean that
thread does not mind whether it is rehomed, unlike C<LGRP_AFF_STRONG>. Load
balancing, dynamic reconfiguration, processor binding, or processor set binding
and manipulation are examples of events that can cause the operating system to
change a thread's home lgroup for which it has a weak affinity.

The C<LGRP_AFF_NONE> affinity signifies no affinity and can be used to remove a
thread's affinity for a particuliar lgroup.  Initially, each thread has no
affinity to any lgroup.  If a thread has no lgroup affinities set, the operating
system chooses a home lgroup for the thread with no affinity set.

Upon successful completion, L<lgrp_affinity_set()> return 1.  Otherwise, it
returns B<undef> and set B<$!> to indicate the error.

=item lgrp_affinity_get($idtype, $id, $lgrp)

The function returns the affinity that the LWP has to a given lgrp. See
L<lgrp_affinity_get()> for detailed description.

=item lgrp_latency_cookie($cookie, $from, $to, [$between=LGRP_LAT_CPU_TO_MEM])

The function takes a cookie representing a snapshot of the lgroup hierarchy and
returns the latency value between a hardware resource in the $from lgroup to a
hardware resource in the $to lgroup. If $from is the same lgroup as $to, the
latency value within that lgroup is returned.

The BETWEEN argument should be set to the following value to specify between
which hardware resources the latency should be measured. Currently the only
valid value is 0 which represents latency from CPU to memory.

Upon successful completion, lgrp_latency_cookie() return 1. Otherwise, it
returns B<undef> and set B<$!> to indicate the error. For LGRP API version 1 the
L<lgrp_latency_cookie()> is an alias for L<lgrp_latency()>.

=item lgrp_latency($from, $to)

The function is similiar to the L<lgrp_latency_cookie()> function, but returns the
latency between the given lgroups at the given instant in time.  Since lgroups
may be freed and reallocated, this function may not be able to provide a
consistent answer across calls.  For that reason, it is recommended that
L<lgrp_latency_cookie()> function be used in its place.

=item lgrp_resources($cookie, $lgrp, $type)

Return the list of lgroups directly containing resources of the specified type.
The resources are represented by a set of lgroups in which each lgroup directly
contains CPU and/or memory resources.

The type can be specified as

=over

=item C<LGRP_RSRC_CPU>

CPU resources

=item C<LGRP_RSRC_MEM>

Memory resources

=back

In case of error B<undef> or empty list is returned and B<$!> is set to indicate
the error.

This function is only available for API version2 and will return B<undef> or
empty list for API version 1 and set $! to C<EINVAL>.

=item lgrp_lgrps($cookie, [$lgrp])

Returns list of all lgroups in a hierarchy starting from $lgrp. If $lgrp is not
specified, uses the value of lgrp_root($cookie). Returns the empty list on
failure.

When called in scalar context, returns the total number of lgroups in the
system.

=item lgrp_leaves($cookie, [$lgrp])

Returns list of all leaf lgroups in a hierarchy starting from $lgrp. If $lgrp is
not specified, uses the value of lgrp_root($cookie). Returns B<undef> or empty
list on failure.

When called in scalar context, returns the total number of leaf in the
system.

=item lgrp_isleaf($cookie, $lgrp)

Returns B<True> if $lgrp is leaf (has no children), B<False> otherwise.

=back

=head2 Object Methods

=over

=item new([$view])

Creates a new Solaris::Lgrp object. An optional argument is passed to
L<lgrp_init()> function. By default uses C<LGRP_VIEW_OS>.

=item cookie()

Returns a transparent cookie that may be passed to functions accepting cookie.

=item version([$version])

Without the argument returns the current version of the L<liblgrp(3LIB)>
library. This is a wrapper for lgrp_version() with L<LGRP_VER_NONE> as the
default version argument.

=item stale()

Returns B<T> if the lgroup information in the object is stale, B<F>
otherwise. It is a wrapper for L<lgrp_cookie_stale()>.

=item view()

Returns the snapshot's view of the lgroup hierarchy. It is a wrapper for
L<lgrp_view()>.

=item root()

Returns the root lgroup. It is a wrapper for L<lgrp_root()>.

=item children($lgrp)

Returns the list of lgroups that are children of the specified lgroup. This is a
wrapper for L<lgrp_children()>.

=item parents($lgrp)

Returns the list of lgroups that are parents of the specified lgroup. This is a
wrapper for L<lgrp_parents()>.

=item nlgrps()

It returns the number of lgroups in the hierarchy. This is a wrapper for
L<lgrp_nlgrps()>.

=item mem_size($lgrp, $type, $content)

Returns the memory size of the given lgroup in bytes. This is a wrapper for
L<lgrp_mem_size()>.

=item cpus($lgrp, $context)

Returns the list of CPUs in the lgroup specified by $lgrp. This is a wrapper for
L<lgrp_cpus()>.

=item resources($lgrp, $type)

Return the list of lgroups directly containing resources of the specified
type. This is a wrapper for L<lgrp_resources()>.

=item home($idtype, $id)

Returns the home lgroup for the given process or thread. This is a wrapper for
L<lgrp_home()>.

=item affinity_get($idtype, $id, $lgrp)

Returns the affinity that the LWP has to a given lgrp. This is a wrapper for
L<lgrp_affinity_get()>.

=item affinity_set($idtype, $id, $lgrp, $affinity)

sets of LWPs specified by the $idtype and $id arguments have for the given lgroup.
This is a wrapper for L<lgrp_affinity_set()>.

=item lgrps([$lgrp])

Returns list of all lgroups in a hierarchy starting from $lgrp (or the
L<lgrp_root()> if $lgrp is not specified). This is a wrapper for L<lgrp_lgrps()>.

=item leaves([$lgrp])

Returns list of all leaf lgroups in a hierarchy starting from $lgrp. If $lgrp is
not specified, uses the value of lgrp_root(). This is a wrapper for
L<lgrp_leaves()>.

=item isleaf($lgrp)

Returns B<True> if $lgrp is leaf (has no children), B<False> otherwise.
This is a wrapper for L<lgrp_isleaf()>.

=item latency($from, $to)

Returns the latency value between a hardware resource in the $from lgroup to a
hardware resource in the $to lgroup. It will use L<lgrp_latency()> for
version 1 of liblgrp(3LIB) and L<lgrp_latency_cookie()> for newer versions.

=back

=head1 COPYRIGHT

Copyright 2005 Sun Microsystems, Inc. All rights reserved. Use is subject to
license terms.

The Solaris::Lgrp module is subject to the terms of the Common Development
and Distribution License (the "License"). You may not use this file except in
compliance with the License.

You can obtain a copy of the license at http://www.opensolaris.org/os/licensing
. See the License for the specific language governing permissions and
limitations under the License.

=head1 SEE ALSO

C<liblgrp(3LIB)>,
C<lgrp_affinity_get(3LGRP)>,
C<lgrp_affinity_set(3LGRP)>,
C<lgrp_children(3LGRP)>,
C<lgrp_cookie_stale(3LGRP)>,
C<lgrp_cpus(3LGRP)>,
C<lgrp_fini(3LGRP)>,
C<lgrp_home(3LGRP)>,
C<lgrp_init(3LGRP)>,
C<lgrp_latency(3LGRP)>,
C<lgrp_mem_size(3LGRP)>,
C<lgrp_nlgrps(3LGRP)>,
C<lgrp_parents(3LGRP)>,
C<lgrp_root(3LGRP)>,
C<lgrp_version(3LGRP)>,
C<lgrp_view(3LGRP)>,
C<lgrp_resources(3LGRP)>,
C<lgrp_latency_cookie(3LGRP)>,

=cut
