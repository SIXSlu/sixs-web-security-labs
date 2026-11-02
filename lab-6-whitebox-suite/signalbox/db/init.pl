#!/usr/bin/env perl
# SignalBox database bootstrap - run at container start (deploy time).
use strict;
use warnings;
use DBI;

my $dbh = DBI->connect('dbi:SQLite:dbname=/opt/signalbox/signalbox.db', '', '',
                       {RaiseError => 1, AutoCommit => 1});

$dbh->do('DROP TABLE IF EXISTS departures');
$dbh->do(<<'SQL');
CREATE TABLE departures (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    time      TEXT NOT NULL,
    destination TEXT NOT NULL,
    platform  TEXT NOT NULL,
    note      TEXT NOT NULL
)
SQL

my @departures = (
    ['09:45', 'Millbrook',            '1', 'Heritage set, all stations'],
    ['10:30', 'Copperline Halt',      '2', 'Market day special'],
    ['11:15', 'Millbrook',            '1', 'Dining car attached'],
    ['12:00', 'Moor Crossing',        '2', 'Branch connection'],
    ['13:40', 'Millbrook',            '1', ''],
    ['14:25', 'Copperline Halt',      '2', 'Photographic stop at the viaduct'],
    ['15:10', 'Millbrook',            '1', ''],
    ['16:00', 'Moor Crossing',        '2', 'Last branch connection of the day'],
    ['17:20', 'Millbrook',            '1', 'Evening dining service'],
);
$dbh->do('INSERT INTO departures (time, destination, platform, note) VALUES (?, ?, ?, ?)',
         undef, @$_) for @departures;

print "signalbox db seeded: " . scalar(@departures) . " departures\n";