package TrackSide;
use Mojo::Base 'Mojolicious', -signatures;

use DBI;

# The fitters' field terminals post straight to the log; the web layer
# keeps no accounts of its own. The session secret is minted at deploy
# time by the entrypoint.
sub startup ($self) {
    $self->secrets([$ENV{TRACKSIDE_SECRET} // 'trackside-dev-secret']);
    $self->sessions->cookie_name('trackside');

    $self->config(hypnotoad => {
        listen   => ['http://0.0.0.0:3000'],
        workers  => 2,
        pid_file => '/opt/trackside/hypnotoad.pid',
    });

    $self->defaults(layout => 'default');

    $self->helper(db => sub ($c) {
        state $dbh = DBI->connect(
            'dbi:SQLite:dbname=/opt/trackside/trackside.db', '', '',
            {RaiseError => 1, AutoCommit => 1});
        return $dbh;
    });

    my $r = $self->routes;

    # defect log (field terminals)
    $r->get('/')->to('entries#index');
    $r->post('/entries')->to('entries#file');
    $r->get('/search')->to('entries#search');

    # shift-handover import (staff tooling)
    $r->post('/staff/import')->to('staff#handover');
}

1;