package FareDesk;
use Mojo::Base 'Mojolicious', -signatures;

use DBI;

# Counter terminals trust the depot SSO, which issues the *signed* session
# cookie. The kiosk itself has no login form and no password store - it
# only trusts that cookie's signature.
#
# TODO rotate before prod
our $DEPOT_SSO_SECRET = 'copperline-staging-2024';

sub startup ($self) {
    $self->secrets([$DEPOT_SSO_SECRET]);
    $self->sessions->cookie_name('faredesk');
    $self->sessions->default_expiration(3600);

    $self->config(hypnotoad => {
        listen   => ['http://0.0.0.0:3000'],
        workers  => 2,
        pid_file => '/opt/faredesk/hypnotoad.pid',
    });

    $self->defaults(layout => 'default');

    # ------------------------------------------------------------------
    # helpers
    # ------------------------------------------------------------------
    $self->helper(db => sub ($c) {
        state $dbh = DBI->connect(
            'dbi:SQLite:dbname=/opt/faredesk/faredesk.db', '', '',
            {RaiseError => 1, AutoCommit => 1});
        return $dbh;
    });

    # ------------------------------------------------------------------
    # routes
    # ------------------------------------------------------------------
    my $r = $self->routes;

    # public counter board
    $r->get('/')->to('tickets#board');
    $r->post('/book')->to('tickets#book');

    # staff console (signed depot-SSO session required)
    my $admin = $r->under('/admin')->to('admin#secure');
    $admin->get('/')->to('admin#console');
    $admin->post('/formula')->to('admin#formula');
    $admin->post('/dispatch')->to('admin#dispatch');
}

1;