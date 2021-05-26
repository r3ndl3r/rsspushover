#!/usr/bin/perl
use warnings;
use strict;
use XML::Feed;
use LWP::UserAgent;
use Find::Lib "$ENV{'HOME'}/scripts";
use RSSDBI;


my $rss = RSSDBI->new(
        table => 'rss',
        dbauth => "$ENV{'HOME'}/.dbi.auth",
        log => "$ENV{'HOME'}/logs/rss.log",
       );


my $pushOver = 1;
my $argv = shift @ARGV;

if (defined $argv && $argv eq '-manage') {
    manFeeds();
    exit;
}


for ($rss->getFeeds) {
    loadItems($_);
}

$rss->log('END SESSION');

sub loadItems {
    my $url = shift;
    my $feed = XML::Feed->parse(URI->new($url));
    
    if (my $error = XML::Feed->errstr()) {
        print "ERROR: $error [ $url ]\n";
        return;
    }

    my $i;
    for my $entry ($feed->entries) {
        ++$i;
        if (!$rss->getItems($url, $entry->title)) {
            $rss->log("New Item: " . $entry->title);

            if ($rss->pushOver($entry->title, $pushOver)) {
                $rss->inItem($url, $entry->title);
                $rss->log("Adding to DB: ".$entry->title);
            }
        }
    }

    $rss->log("Update got [$i] items for $url");
}


sub manFeeds {
    print "[L]ist [D]elete [A]dd [Q]uit : ";

    while (chomp(my $in = uc <STDIN>)) {

        if ($in eq 'L') {
            feedList();
            
        } elsif ($in eq 'D') {
            feedDel();

        } elsif ($in eq 'A') {
            feedAdd();

        } elsif ($in eq 'Q') {
            exit;

        } else {
            print "\nFail! Choose Again: [L|D|A|Q].\n\n";
            manFeeds();

        }
    }
}


sub feedList {
    $rss->liFeeds();

    manFeeds();
}


sub feedAdd {
    print "Link To Add: ";

    chomp( my $link = <STDIN> );

    $pushOver = 0;

    $rss->addFeed($link);

    print "\nAdded: $link\nUpdating items . . . . . . . .\n";

    loadItems($link);

    manFeeds();
}


sub feedDel {
    $rss->liFeeds();

    print "Delete Feed Number : ";

    my @links = $rss->getFeeds; 
    chomp ( my $number = <STDIN> );

    if ($number =~ /^\d+$/ && $number > 0) {
        --$number;
        if ($links[$number]) {
            $rss->delFeed($links[$number]);
        } else {
            print "\nInvalid Number!\n\n";
            feedDel();
        }
    } else {
        print "\nInvalid Number!\n\n";
        feedDel();
    }

    manFeeds();
}
