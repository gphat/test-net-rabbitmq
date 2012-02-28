package Test::Net::RabbitMQ;
use Moose;
use warnings;
use strict;

our $VERSION = '0.08';

# Bindings are stored in the following form:
# {
#   exchange_name => {
#      regex => queue_name
#   },
#   ...
# }
has bindings => (
    traits => [ qw(Hash) ],
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
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

has debug => (
    is => 'rw',
    isa => 'Bool',
    default => 0
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

has delivery_tag => (
    traits  => [ qw(Counter) ],
    is      => 'ro',
    isa     => 'Num',
    default => 0,
    handles => {
        _inc_delivery_tag   => 'inc',
        _dec_delivery_tag   => 'dec',
        _reset_delivery_tag => 'reset',
    },
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

    die "Unknown queue: $queue" unless $self->_queue_exists($queue);

    my $message = shift(@{ $self->_get_queue($queue) });

    return undef unless defined($message);

    $message->{delivery_tag}  = $self->_inc_delivery_tag;
    $message->{content_type}  = '';
    $message->{redelivered}   = 0;
    $message->{message_count} = 0;

    return $message;
}

sub queue_bind {
    my ($self, $channel, $queue, $exchange, $pattern) = @_;

    die "Not connected" unless $self->connected;

    die "Unknown channel: $channel" unless $self->_channel_exists($channel);

    die "Unknown queue: $queue" unless $self->_queue_exists($queue);

    die "Unknown exchange: $exchange" unless $self->_exchange_exists($exchange);

    my $binds = $self->bindings->{$exchange} || {};

    # Turn the pattern we're given into an actual regex
    my $regex = $pattern;
    if(($pattern =~ /\#/) || ($pattern =~ /\*/)) {
        if($pattern =~ /\#/) {
            $regex =~ s/\#/\.\*/g;
        } elsif($pattern =~ /\*/) {
            $regex =~ s/\*/\[^\.]\*/g;
        }
        $regex = '^'.$regex.'$';
        $regex = qr($regex);
    } else {
        $regex = qr/^$pattern$/;
    }

    # $self->_set_binding($routing_key, { queue => $queue, exchange => $exchange });
    $binds->{$regex} = $queue;

    # In case these are new bindings
    $self->bindings->{$exchange} = $binds;
}

sub queue_declare {
    my ($self, $channel, $queue, $options) = @_;

    die "Not connected" unless $self->connected;

    die "Unknown channel: $channel" unless $self->_channel_exists($channel);

    $self->_set_queue($queue, []);
}

sub queue_unbind {
    my ($self, $channel, $queue, $exchange, $routing_key) = @_;

    die "Not connected" unless $self->connected;

    die "Unknown channel: $channel" unless $self->_channel_exists($channel);

    die "Unknown queue: $queue" unless $self->_queue_exists($queue);

    die "Unknown exchange: $queue" unless $self->_exchange_exists($exchange);

    die "Unknown routing: $routing_key" unless $self->_binding_exists($routing_key);

    $self->_remove_binding($routing_key);
}

sub publish {
    my ($self, $channel, $routing_key, $body, $options, $props) = @_;

    die "Not connected" unless $self->connected;

    die "Unknown channel: $channel" unless $self->_channel_exists($channel);

    my $exchange = $options->{exchange};
    unless($exchange) {
        $exchange = 'amq.direct';
    }

    die "Unknown exchange: $exchange" unless $self->_exchange_exists($exchange);

    # Get the bindings for the specified exchange and test each key to see
    # if our routing key matches.  If it does, push it into the queue
    my $binds = $self->bindings->{$exchange};
    foreach my $pattern (keys %{ $binds }) {
        if($routing_key =~ $pattern) {
            print STDERR "Publishing '$routing_key' to ".$binds->{$pattern}."\n" if $self->debug;
            my $message = {
                body         => $body,
                routing_key  => $routing_key,
                exchange     => $exchange,
                props        => $props,
            };
            push(@{ $self->_get_queue($binds->{$pattern}) }, $message);
        }
    }
}

sub recv {
    my ($self) = @_;

    die "Not connected" unless $self->connected;

    my $queue = $self->queue;
    die "No queue, did you consume() first?" unless defined($queue);

    my $message = shift(@{ $self->_get_queue($self->queue) });

    return undef unless defined $message;

    $message->{delivery_tag} = $self->_inc_delivery_tag;
    $message->{consumer_tag} = '';

    return $message;
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

This module has all the features I've needed to successfully test our 
RabbitMQ-using application. Patches are welcome if I'm missing something you
need! At the moment there are a number of shortcomings:

=over 4

=item C<recv> doesn't block

=item exchanges are all topic

=item lots of other stuff!

=back
 
=head1 ATTRIBUTES

=head2 connectable

If false then any calls to connect will die to emulate a failed connection.

=head2 debug

If set to true (which you can do at any time) then a message will be emmitted
to STDERR any time a message is added to a queue.

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

Like C<Net::RabbitMQ>, this will return a hash containing the following
information:

     {
       body => 'Magic Transient Payload', # the reconstructed body
       routing_key => 'nr_test_q',        # route the message took
       exchange => 'nr_test_x',           # exchange used
       delivery_tag => 1,                 # (inc'd every recv or get)
       redelivered => 0,                  # always 0
       message_count => 0,                # always 0
     }

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

Like C<Net::RabbitMQ>, this will return a hash containing the following
information:

     {
       body => 'Magic Transient Payload', # the reconstructed body
       routing_key => 'nr_test_q',        # route the message took
       exchange => 'nr_test_x',           # exchange used
       delivery_tag => 1,                 # (inc'd every recv or get)
       consumer_tag => '',                # Always blank currently
       props => $props,                   # hashref sent in
     }

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
