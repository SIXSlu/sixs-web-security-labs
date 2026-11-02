package SignalBox::Controller::Ops;
use Mojo::Base 'Mojolicious::Controller', -signatures;

# The signalman's ops console: unlock with the commissioning PIN, then
# queue announcements on the board. The shift-log tail box below is
# mirrored on the platform information displays, so it stays world
# readable; the announcer behind /ops/broadcast is PIN-gated.

sub unlock ($c) {
    my $pin = $c->param('pin') // '';
    my $expected = _pin();

    if (length($expected) && $pin eq $expected) {
        $c->session(signalman => 1);
        return $c->render(text => 'unlocked');
    }
    $c->render(text => 'wrong pin', status => 403);
}

sub secure ($c) {
    return 1 if $c->session('signalman');
    $c->render(text => 'signalman session required', status => 403);
    return undef;
}

sub tail ($c) {
    # The tail logbox shows a shift log straight on the console. Only
    # relative names from the log directory make sense here - no
    # absolute paths, no traversal.
    my $src = $c->param('src') // '';
    return $c->render(text => 'bad path')
        if $src =~ m{^/} || $src =~ /\.\./;

    open(my $fh, $src)
        or return $c->render(text => "cannot open $src", status => 404);
    my $out = do { local $/; <$fh> };
    close $fh;

    $c->render(text => (defined $out ? $out : ''));
}

sub broadcast ($c) {
    # Queue a one-line announcement on the platform displays; the
    # announce helper does the actual laying of the text.
    my $text = $c->param('text') // '';

    chomp(my $out = qx{/opt/signalbox/bin/announce $text});
    $c->render(text => "board updated: $out");
}

sub _pin {
    open(my $fh, '<', '/opt/signalbox/board.conf') or return '';
    while (my $line = <$fh>) {
        return $1 if $line =~ /^\s*signalman_pin\s*=\s*(\S+)/;
    }
    close $fh;
    return '';
}

1;