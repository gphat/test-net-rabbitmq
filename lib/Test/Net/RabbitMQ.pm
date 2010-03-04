package Test::Net::RabbitMQ;
use Moose;
use warnings;
use strict;

our $VERSION = '0.01';

has bindings => (
    traits => [ qw(Hash) ],
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    handles => {
        _binding_exists => 'exists',
        _get_bindind    => 'get',
        _remove_binding => 'delete',
        _set_binding    => 'set',
    }
);

has connectable => (
    is => 'rw',
    isa => 'Bool',
    default => 1
);

has connected => (
    is => 'rw',
    isa => 'Bool',
    default => 0
);

has channels => (
    traits => [ qw(Hash) ],
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    handles => {
        _channel_exists => 'exists',
        _get_channel    => 'get',
        _remove_channel => 'delete',
        _set_channel    => 'set',
    }
);

has exchanges => (
    traits => [ qw(Hash) ],
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    handles => {
        _exchange_exists => 'exists',
        _get_exchange    => 'get',
        _remove_exchange => 'delete',
        _set_exchange    => 'set',
    }
);

has queues => (
    traits => [ qw(Hash) ],
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    handles => {
        _queue_exists => 'exists',
        _get_queue    => 'get',
        _remove_queue => 'delete',
        _set_queue    => 'set',
    }
);

sub channel_open {
    my ($self, $channel) = @_;

    die "Not connected" unless $self->connected;

    $self->_set_channel($channel, 1);
}

sub channel_close {
    my ($self, $channel) = @_;

    die "Not connected" unless $self->connected;

    die "Unknown channel: $channel" unless $self->_channel_exists($channel);

    $self->_remove_channel($channel);
}

sub connect {
    my ($self) = @_;

    die('Unable to connect!') unless $self->connectable;

    $self->connected(1);
}

sub disconnect {
    my ($self) = @_;

    $self->connected(0);
}

sub exchange_declare {
    my ($self, $channel, $exchange, $options) = @_;

    die "Not connected" unless $self->connected;

    die "Unknown channel" unless $self->_channel_exists($channel);

    $self->_set_exchange($exchange, 1);
}

sub queue_bind {
    my ($self, $channel, $queue, $exchange, $routing_key) = @_;

    die "Not connected" unless $self->connected;

    die "Unknown channel" unless $self->_channel_exists($channel);

    die "Unknown queue" unless $self->_queue_exists($queue);

    die "Unknown exchange" unless $self->_exchange_exists($exchange);

    $self->_set_binding($routing_key, { queue => $queue, exchange => $exchange });
}

sub queue_declare {
    my ($self, $channel, $queue, $options) = @_;

    die "Not connected" unless $self->connected;

    die "Unknown channel" unless $self->_channel_exists($channel);

    $self->_set_queue($queue, []);
}

1;

=head1 NAME

Test::Net::RabbitMQ - The great new Test::Net::RabbitMQ!

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Test::Net::RabbitMQ;

    my $foo = Test::Net::RabbitMQ->new();
    ...

=head1 ATTRIBUTES

=head2 connectable

If false then any calls to connect will die to emulate a failed connection.

=head1 AUTHOR

Cory G Watson, C<< <gphat at cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Cory G Watson.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Test::Net::RabbitMQ
