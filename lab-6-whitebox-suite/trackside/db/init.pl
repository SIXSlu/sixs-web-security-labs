#!/usr/bin/env perl
# TrackSide database bootstrap - run at container start (deploy time).
use strict;
use warnings;
use DBI;

my $dbh = DBI->connect('dbi:SQLite:dbname=/opt/trackside/trackside.db', '', '',
                       {RaiseError => 1, AutoCommit => 1});

$dbh->do('DROP TABLE IF EXISTS entries');
$dbh->do(<<'SQL');
CREATE TABLE entries (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    unit    TEXT NOT NULL,
    summary TEXT NOT NULL,
    body    TEXT NOT NULL,
    filed_at TEXT NOT NULL
)
SQL

my @entries = (
    ['BR-04',   'Brake block wear beyond limit',
     'Rear brake block on brake van BR-04 worn past the wear line during the Millbrook turn. Blocks replaced, bedding-in runs scheduled before the weekend service.'],
    ['LOCO-9',  'Sand box refill required',
     'Sand box on LOCO-9 ran dry on the bank towards Copperline Halt. Refilled from the depot stores. Watch the adhesion on wet rail in the cutting.'],
    ['SIG-2',   'Lamp lens cracked',
     'Distant signal lens at the Copperline Halt end has a hairline crack. Temporary lens fitted; permanent replacement on order from the signalling stores.'],
    ['CARR-11', 'Door interlock sticking',
     'Third-door interlock on CARR-11 intermittently fails to latch when the door is slammed. Passengers advised to close gently. Lubrication and adjustment done.'],
    ['WAY-6',   'Vegetation encroaching sight lines',
     'Hawthorn on the embankment near way marker 6 is closing down the driver sight line for the Millbrook crossing. Cutting crew booked for the next maintenance possession.'],
    ['BR-04',   'Handbrake travel adjusted',
     'Handbrake travel on BR-04 was long after the brake block change. Ratchet adjusted and tested on the depot grade. Recheck after the next outing.'],
    ['LOCO-3',  'Whistle valve weeping',
     'Whistle valve on LOCO-3 weeps under full pressure; a slow loss of steam over a long layover. Valve lapped in on the bench, reseated and tested to working pressure.'],
    ['WATER-1', 'Column hose washer perished',
     'Water column hose washer at Millbrook perished and sprayed the platform. Washer renewed, spare hose kept in the van.'],
);
$dbh->do('INSERT INTO entries (unit, summary, body, filed_at) VALUES (?, ?, ?, datetime("now"))',
         undef, @$_) for @entries;

print "trackside db seeded: " . scalar(@entries) . " entries\n";