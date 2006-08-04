<?php
//
// JBoss, the OpenSource J2EE webOS
//
// Distributable under LGPL license.
// See terms of license at gnu.org.
//

// Steps to do before connecting: (As postgres@jfcexpert for example).
// 1 - Initialize postgresql. (/usr/local/pgsql/bin/initdb -D /usr/local/pgsql/data) 
// 2 - Start postmaster. (/usr/lib/postgresql/bin/pg_ctl -D /usr/local/pgsql/data -l logfile start)
// 3 - Create database. (/usr/lib/postgresql/bin/createdb test)
// 4 - Create the user and the tables via psql. (/usr/lib/postgresql/bin/psql test).
/*
 CREATE USER www PASSWORD 'foo';
 create table authors (title text NOT NULL);
 insert into authors (title) values ( 'moi' );
 ALTER TABLE authors OWNER TO www;
 (Alter owner otherwise www can't use it).
 */
// check /etc/postgresql/pg_hba.conf (tell password for localhost (IDENT not running).
//
// Connecting, selecting database
$dbconn = pg_connect("host=localhost dbname=test user=www password=foo")
    or die('Could not connect: ' . pg_last_error());

// Performing SQL query
$query = 'SELECT * FROM authors';
$result = pg_query($query) or die('Query failed: ' . pg_last_error());

// Printing results in HTML
echo "<table>\n";
while ($line = pg_fetch_array($result, null, PGSQL_ASSOC)) {
    echo "\t<tr>\n";
    foreach ($line as $col_value) {
            echo "\t\t<td>$col_value</td>\n";
    }
    echo "\t</tr>\n";
}
echo "</table>\n";

// Free resultset
pg_free_result($result);

// Closing connection
pg_close($dbconn);
?>
