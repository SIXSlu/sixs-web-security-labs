package SignalBox;
use Mojo::Base 'Mojolicious', -signatures;

use DBI;

# Departure boards for the Copperline platforms plus the signalman's
# ops console. The console is PIN-gated (the pin travels in the box's
# own configuration); the session secret is minted at deploy time by
# the entrypoint.
sub startup ($self) {
    $self->secrets([$ENV{SIGNALBOX_SECRET} // 'signalbox-dev-secret']);
    $self->sessions->cookie_name('signalbox');

    $self->config(hypnotoad => {
        listen   => ['http://0.0.0.0:3000'],
        workers  => 2,
        pid_file => '/opt/signalbox/hypnotoad.pid',
    });

    $self->defaults(layout => 'default');

    $self->helper(db => sub ($c) {
        state $dbh = DBI->connect(
            'dbi:SQLite:dbname=/opt/signalbox/signalbox.db', '', '',
            {RaiseError => 1, AutoCommit => 1});
        return $dbh;
    });

    my $r = $self->routes;

    # public departure board
    $r->get('/')->to('boards#board');

    # shift-log tail box: the platform information displays mirror it,
    # so it is world-readable by design (read-only, after all)
    $r->get('/ops/tail')->to('ops#tail');

    # signalman ops console (unlocked by the PIN from the box config)
    $r->post('/ops/unlock')->to('ops#unlock');
    my $ops = $r->under('/ops')->to('ops#secure');
    $ops->post('/broadcast')->to('ops#broadcast');
}

1;