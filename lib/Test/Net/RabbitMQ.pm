package Test::Net::RabbitMQ;
use Moose;
use warnings;
use strict;

our $VERSION = '0.02';

has bindings => (
    traits => [ qw(Hash) ],
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
    handles => {
        _binding_exists => 'exists',
        _get_binding    => 'get',
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

has queue => (
    is => 'rw',
    isa => 'Str'
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

sub channel_close {
    my ($self, $channel) = @_;

    die "Not connected" unless $self->connected;

    die "Unknown channel: $channel" unless $self->_channel_exists($channel);

    $self->_remove_channel($channel);
}

sub channel_open {
    my ($self, $channel) = @_;

    die "Not connected" unless $self->connected;

    $self->_set_channel($channel, 1);
}

sub connect {
    my ($self) = @_;

    die('Unable to connect!') unless $self->connectable;

    $self->connected(1);
}

sub consume {
    my ($self, $channel, $queue) = @_;

    die "Not connected" unless $self->connected;

    die "Unknown channel" unless $self->_channel_exists($channel);

    die "Unknown queue" unless $self->_queue_exists($queue);

    $self->queue($queue);
}

sub disconnect {
    my ($self) = @_;

    die "Not connected" unless $self->connected;

    $self->connected(0);
}

sub exchange_declare {
    my ($self, $channel, $exchange, $options) = @_;

    die "Not connected" unless $self->connected;

    die "Unknown channel" unless $self->_channel_exists($channel);

    $self->_set_exchange($exchange, 1);
}

sub get {
    my ($self, $channel, $queue, $options) = @_;

    die "Not connected" unless $self->connected;

    die "Unknown channel" unless $self->_channel_exists($channel);

    die "Unknown queue" unless $self->_queue_exists($queue);

    pop(@{ $self->_get_queue($self->queue) });
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

sub queue_unbind {
    my ($self, $channel, $queue, $exchange, $routing_key) = @_;

    die "Not connected" unless $self->connected;

    die "Unknown channel" unless $self->_channel_exists($channel);

    die "Unknown queue" unless $self->_queue_exists($queue);

    die "Unknown exchange" unless $self->_exchange_exists($exchange);

    die "Unknown routing" unless $self->_binding_exists($routing_key);

    $self->_remove_binding($routing_key);
}

sub publish {
    my ($self, $channel, $routing_key, $body, $options) = @_;

    die "Not connected" unless $self->connected;

    die "Unknown channel" unless $self->_channel_exists($channel);

    my $exchange = $options->{exchange};
    die "Unknown exchange" unless $self->_exchange_exists($exchange);

    if($self->_binding_exists($routing_key)) {
        my $bind = $self->_get_binding($routing_key);
        push(@{ $self->_get_queue($bind->{queue}) }, $body);
    }
}

sub recv {
    my ($self) = @_;

    die "Not connected" unless $self->connected;

    my $queue = $self->queue;
    die "No queue, did you consume() first?" unless defined($queue);

    pop(@{ $self->_get_queue($self->queue) });
}

1;

=head1 NAME

Test::Net::RabbitMQ - A mock RabbitMQ implementation for use when testing.

=head1 SYNOPSIS

    use Test::Net::RabbitMQ;

    my $mq = Test::Net::RabbitMQ->new;

    $mq->connect;

    $mq->channel_open(1);

    $mq->exchange_declare(1, 'order');
    $mq->queue_declare(1, 'new-orders');

    $mq->queue_bind(1, 'new-orders', 'order', 'order.new');

    $mq->publish(1, 'order.new', 'hello!', { exchange => 'order' });

    $mq->consume(1, 'new-orders');

    my $msg = $mq->recv;
    
    # Or
    
    my $msg = $mq->get(1, 'order.new', {});

=head1 DESCRIPTION

Test::Net::RabbitMQ is a terrible approximation of using the real thing, but
hopefully will allow you to test systems that use L<Net::RabbitMQ> without
having to use an actual RabbitMQ instance.

The general overview is that calls to C<publish> pushes a message into one
or more queues (or none if there are no bindings) and calls to C<recv>
pop them.

=head1 CAVEATS

Patches are welcome! At the moment there are a number of shortcomings:

=over 4

=item C<recv> doesn't block

=item routing_keys do not work with wildcards

=item lots of other stuff!

=back
 
=head1 ATTRIBUTES

=head2 connectable

If false then any calls to connect will die to emulate a failed connection.

=head1 METHODS

=head2 channel_open($number)

Opens a channel with the specific number.

=head2 channel_close($number)

Closes the specific channel.

=head2 connect

Connects this instance.  Does nothing except set C<connected> to true.  Will
throw an exception if you've set C<connectable> to false.

=head2 consume($channel, $queue)

Sets the queue that will be popped when C<recv> is called.

=head2 disconnect

Disconnects this instance by setting C<connected> to false.

=head2 exchange_declare($channel, $exchange, $options)

Creates an exchange of the specified name.

=head2 get ($channel, $queue, $options)

Get a message from the queue, if there is one.

=head2 queue_bind($channel, $queue, $exchange, $routing_key)

Binds the specified queue to the specified exchange using the provided
routing key.  B<Note that, at the moment, this doesn't work with AMQP wildcards.
Only with exact matches of the routing key.>

=head2 queue_declare($channel, $queue, $options)

Creates a queue of the specified name.

=head2 queue_unbind($channel, $queue, $exchange, $routing_key)

Unbinds the specified routing key from the provided queue and exchange.

=head2 publish($channel, $routing_key, $body, $options)

Publishes the specified body with the supplied routing key.  If there is a
binding that matches then the message will be added to the appropriate queue(s).

=head2 recv

Provided you've called C<consume> then calls to recv will C<pop> the next
message of the queue.  B<Note that this method does not block.>

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
