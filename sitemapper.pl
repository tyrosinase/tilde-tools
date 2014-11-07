#!/usr/bin/perl -w

use strict;
# tilde.club sitemapper
# by Karen Cravens (~silver)
use WWW::RobotRules;
use LWP::Simple qw(get);
use POSIX qw(strftime);
use JSON::PP;

my $rootdir = '/home/';
my $rooturl = 'http://tilde.club/~';
my $webdir = '/public_html';
my $killfile = '/home/brendn/bin/botify/killfile';
my $denyfile = '/home/silver/bin/allowdeny.txt';
my $ignores = {};
my $denies = {};
my $allows = {};
my $rules = WWW::RobotRules->new('Tildemapper/1.0');
my $map = {};
my $updates = {};
my $byuser = '/home/silver/public_html/sitemap.html';
my $bypage = '/home/silver/public_html/sitemap2.html';
my $byjson = '/home/silver/public_html/sitemap.json';

open my $fh, '<', $killfile || die;
while (<$fh>) {
	chomp;
	$ignores->{$_} = 1;
}
close $fh;

open $fh, '<', $denyfile || die;
while (my $line = <$fh>) {
	chomp $line;
	if ($line =~ /^(.*?)\s(.*)$/) {
		if ($1 eq 'allow') {
			$allows->{$2} = 1;
		}
		elsif ($1 eq 'deny') {
			$denies->{$2} = 1;
		}
		else {
			die "Did not recognize allow/deny $1\n";
		}
	}
}
close $fh;

opendir(my $dh, $rootdir) || die;
while (readdir $dh) {
        my $username = $_;
	$updates->{$username} = 0;
	if ($ignores->{$username}) {
#		$map->{$rooturl . $username . '/index.html'} = {
#			file => $rootdir . $username . $webdir . '/index.html', 
#			username => $username,
#			name => "Killfiled", 
#			private => 1,
#			mtime => 0,
#		};
		next;
	}
        if (-d $rootdir . $username . $webdir) {
                checkdir ($username, q{});
        }
}
closedir $dh;

open my $bph, '>', $bypage;
open my $buh, '>', $byuser;

print $bph '<!doctype html><html itemscope="" itemtype="http://schema.org/WebPage" lang="en"><head><title>Tildemap (date)</title></head><body>', "\n";
print $buh '<!doctype html><html itemscope="" itemtype="http://schema.org/WebPage" lang="en"><head><title>Tildemap (user)</title></head><body>', "\n";
print $bph '<h1>Sitemap</h1>', "\n";
print $buh '<h1>Sitemap by user</h1>', "\n";
print $bph '<p><a href="sitemap.html">Sitemap by user</a></p>', "\n";
print $buh '<p><a href="sitemap2.html">Sitemap by date</a></p>', "\n";

my $username = q{};
foreach my $uri (sort {
	$updates->{$map->{$b}->{username}} <=> $updates->{$map->{$a}->{username}}
	|| $map->{$b}->{mtime} <=> $map->{$a}->{mtime}
} keys $map) {
	next if $map->{$uri}->{private};
	if ($username ne $map->{$uri}->{username}) {
		$username = $map->{$uri}->{username};
		print $buh "<h3>$username - ", strftime("%d-%b-%Y %H:%M", gmtime($updates->{$username})), "<\/h3>\n";
	}
	print $buh '<p><a href="' , $uri, '">', $map->{$uri}->{name}, '</a> - ', strftime("%d-%b-%Y %H:%M", gmtime($map->{$uri}->{mtime})), '</p>', "\n";
}

my $date = q{};
foreach my $uri (sort {$map->{$b}->{mtime} <=> $map->{$a}->{mtime}} keys $map) {
	next if $map->{$uri}->{private};
	if ($date ne strftime("%d-%b-%Y", gmtime($map->{$uri}->{mtime}))) {
		$date = strftime("%d-%b-%Y", gmtime($map->{$uri}->{mtime}));
		print $bph "<h3>$date</h3>\n";
	}
	print $bph '<p><a href="http://tilde.club/~', $map->{$uri}->{'username'}, '/">', $map->{$uri}->{'username'}, '</a>: <a href="' , $uri, '">', $map->{$uri}->{name}, '</a></p>', "\n";
}
print $buh '<hr><p>Respects killfile at /home/brendn/bin/botify/killfile and robots.txt in each directory.</p>', "\n";
print $buh '<p>Directories can be chmod o-r to prevent local browsing (including this script) but still allow web serving.</p>', "\n";
print $bph '<p>Last updated: ', strftime("%d-%b-%Y %H:%M", gmtime()), "</p>\n";
print $buh '</body></html>', "\n";
print $bph '<hr><p>Respects killfile at /home/brendn/bin/botify/killfile and robots.txt in each directory.</p>', "\n";
print $bph '<p>Directories can be chmod o-r to prevent local browsing (including this script) but still allow web serving.</p>', "\n";
print $bph '<p>Last updated: ', strftime("%d-%b-%Y %H:%M", gmtime()), "</p>\n";
print $bph '</body></html>', "\n";

close $buh;
close $bph;

open my $bjh, '>', $byjson;
print $bjh encode_json $map;
close $bjh;

sub checkdir {
        my $username = shift;
        my $dircheck = shift;

	if (!-r $rootdir . $username . $webdir . $dircheck) {
#		$map->{$rooturl . $username . $dircheck . '/index.html'} = {
#			file => $rootdir . $username . $webdir . '/index.html', 
#			username => $username,
#			name => "Directory not publicly readable", 
#			private => 1,
#			mtime => 0,
#		};
		return;
	}
	{
		my $url = $rooturl . $username . $dircheck . '/robots.txt';
		my $robots_txt = get $url;
		$rules->parse($url, $robots_txt) if defined $robots_txt;
	}
        opendir(my $wdh, $rootdir . $username . $webdir . $dircheck) || die $rootdir . $username . $webdir . $dircheck . ': ' . $!;
        while (readdir $wdh) {
                my $filename = $_;
                next if $filename =~ /^\./; # hidden
		my $fullfile = $rootdir . $username . $webdir . $dircheck . '/' . $filename;
		next if (exists $denies->{$fullfile}); 
		next if (exists $denies->{$rootdir . $username . $webdir . $dircheck} && !exists $allows->{$fullfile}); 
		next if (-l $fullfile); # symbolic
		next if !$rules->allowed("$rooturl$username$dircheck/$filename");
                if (-d $fullfile) {
                        checkdir ($username, $dircheck . '/' . $filename);
                        next;
                }
                next if $filename !~ /^(.*?)\.html$/; # not a vanilla page
		my $name = $dircheck . ' ' . $1;
		if ($name eq ' index') {
			$name = '<b>Home Page</b>';
		}
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($fullfile);
		if ($mtime > $updates->{$username}) {
			$updates->{$username} = $mtime;
		}
		$map->{"$rooturl$username$dircheck/$filename"} = {
			file => $fullfile,
			username => $username,
			name => $name, 
			ctime => $ctime,
			mtime => $mtime,
			size => $size,
			private => 0,
		};
        }
}

