# DBDish::mysql.pm6

use NativeCall;
use DBDish;     # roles for drivers

#module DBDish:auth<mberends>:ver<0.0.1>;

#------------ mysql library functions in alphabetical order ------------

sub mysql_affected_rows( OpaquePointer $mysql_client )
    returns int32
    is native('libmysqlclient')
    { ... }

sub mysql_close( OpaquePointer $mysql_client )
    is native('libmysqlclient')
    { ... }

sub mysql_error( OpaquePointer $mysql_client)
    returns str
    is native('libmysqlclient')
    { ... }

sub mysql_fetch_field( OpaquePointer $result_set )
    returns CArray[Str]
    is native('libmysqlclient')
    { ... }

sub mysql_fetch_row( OpaquePointer $result_set )
    returns CArray[Str]
    is native('libmysqlclient')
    { ... }

sub mysql_field_count( OpaquePointer $mysql_client )
    returns uint32
    is native('libmysqlclient')
    { ... }

sub mysql_free_result( OpaquePointer $result_set )
    is native('libmysqlclient')
    { ... }

sub mysql_init( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_insert_id( OpaquePointer $mysql_client )
    returns uint64
    is native('libmysqlclient')
    { ... }

sub mysql_num_rows( OpaquePointer $result_set )
    returns Int
    is native('libmysqlclient')
    { ... }

sub mysql_query( OpaquePointer $mysql_client, str $sql_command )
    returns int32
    is native('libmysqlclient')
    { ... }

sub mysql_real_connect( OpaquePointer $mysql_client, Str $host, Str $user,
    Str $password, Str $database, int32 $port, Str $socket, Int $flag )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_use_result( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_warning_count( OpaquePointer $mysql_client )
    returns uint32
    is native('libmysqlclient')
    { ... }

sub mysql_stmt_init( OpaquePointer $mysql_client )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_stmt_prepare( OpaquePointer $mysql_stmt, Str, Int $length )
    returns OpaquePointer
    is native('libmysqlclient')
    { ... }

sub mysql_ping(OpaquePointer $mysql_client)
    returns int32
    is native('libmysqlclient')
    { ... }

#-----------------------------------------------------------------------

class DBDish::mysql::StatementHandle does DBDish::StatementHandle {
    has $!mysql_client;
    has $!statement;
    has $!result_set;
    has $!affected_rows;
    has @!column_names;
    has $!field_count;
    has $.mysql_warning_count is rw = 0;
    
    submethod BUILD(:$!mysql_client, :$!statement) { }
    
    method execute(*@params is copy) {
        # warn "in DBDish::mysql::StatementHandle.execute()";
        my $statement = '';
        my @chunks = $!statement.split('?', @params + 1);
        my $last-chunk = @chunks.pop;
        for @chunks {
            $statement ~= $_;
            my $param = @params.shift;
            if $param.defined {
                if $param ~~ Real {
                    $statement ~= $param 
                }
                else {
                    $statement ~= self.quote($param.Str);
                }
            }
            else {
                $statement ~= 'NULL';
            }
        }
        $statement ~= $last-chunk;
        # note "in DBDish::mysql::StatementHandle.execute statement=$statement";
        $!result_set = Mu;
        my $status = mysql_query( $!mysql_client, $statement ); # 0 means OK
        $.mysql_warning_count = mysql_warning_count( $!mysql_client );
        self!reset_errstr();
        if $status != 0 {
            self!set_errstr(mysql_error( $!mysql_client ));
        }

        my $rows = self.rows;
        return ($rows == 0) ?? "0E0" !! $rows;
    }

    method escape(Str $x) {
        # XXX should really call mysql_real_scape_string
        $x.trans(
                [q['],  q["],  q[\\],   chr(0), "\r", "\n"]
            =>  [q[\'], q[\"], q[\\\\], '\0',   '\r', '\n']
        );
    }
    method quote(Str $x) {
        q['] ~ self.escape($x) ~ q['];
    }

    # do() and execute() return the number of affected rows directly or:
    # rows() is called on the statement handle $sth.
    method rows() {
        unless defined $!affected_rows {
            self!reset_errstr();
            $!affected_rows = mysql_affected_rows($!mysql_client);
            my $errstr      = mysql_error( $!mysql_client );

            if $errstr ne '' { self!set_errstr($errstr); }
        }
        
        if defined $!affected_rows {
            return $!affected_rows;
        } 
    }

    method fetchrow() {
        my @row_array;

        unless defined $!result_set {
            $!result_set  = mysql_use_result( $!mysql_client);
            $!field_count = mysql_field_count($!mysql_client);
        }

        if defined $!result_set {
            # warn "fetching a row";
            self!reset_errstr();

            my $native_row = mysql_fetch_row($!result_set); # can return NULL
            my $errstr     = mysql_error( $!mysql_client );
            
            if $errstr ne '' { self!set_errstr($errstr); }
            
            if $native_row {
                loop ( my $i=0; $i < $!field_count; $i++ ) {
                    @row_array.push($native_row[$i]);
                }
            }
            else { self.finish; }
        }
        return @row_array;
    }
    method column_names {
        unless @!column_names {
            unless defined $!result_set {
                $!result_set  = mysql_use_result( $!mysql_client);
                $!field_count = mysql_field_count($!mysql_client);
            }
            loop ( my $i=0; $i < $!field_count; $i++ ) {
                my $field_info  = mysql_fetch_field($!result_set);
                my $column_name = $field_info[0];
                @!column_names.push($column_name);    
            }
        }
        @!column_names;
    }

    method mysql_insertid() {
        mysql_insert_id($!mysql_client);
        # but Parrot NCI cannot return an unsigned long long :-(
    }

    method finish() {
        self.fetchrow if !defined $!result_set; 
        if defined( $!result_set ) {
            mysql_free_result($!result_set);
            $!result_set   = Mu;
            @!column_names = Mu;
        }
        return Bool::True;
    }
}

class DBDish::mysql::Connection does DBDish::Connection {
    has $!mysql_client;
    submethod BUILD(:$!mysql_client) { }
    method prepare( Str $statement ) {
        # warn "in DBDish::mysql::Connection.prepare()";
        my $statement_handle = DBDish::mysql::StatementHandle.new(
            mysql_client => $!mysql_client,
            statement    => $statement,
            RaiseError   => $.RaiseError
        );
        return $statement_handle;
    }
    method mysql_insertid() {
        mysql_insert_id($!mysql_client);
        # but Parrot NCI cannot return an unsigned  long long :-(
    }

    method ping() {
        0 == mysql_ping($!mysql_client);
    }

    method disconnect() {
        mysql_close($!mysql_client);
        True
    }

    method quote-identifer(Str:D $name) {
        qq[`$name`];
    }
}

class DBDish::mysql:auth<mberends>:ver<0.0.1> {

    has $.Version = 0.01;

#------------------ methods to be called from DBIish ------------------
    method connect(Str :$user, Str :$password, :$RaiseError, *%params ) {
        # warn "in DBDish::mysql.connect('$user',*,'$params')";
        my ( $mysql_client, $mysql_error );
        unless defined $mysql_client {
            $mysql_client = mysql_init( OpaquePointer );
            $mysql_error  = mysql_error( $mysql_client );
        }
        my $host     = %params<host>     // 'localhost';
        my $port     = (%params<port>     // 0).Int;
        my $database = %params<database> // 'mysql';
        my $socket   = %params<socket> // OpaquePointer;
        # real_connect() returns either the same client pointer or null
        my $result   = mysql_real_connect( $mysql_client, $host,
            $user, $password, $database, $port, $socket, 0 );
        my $error = mysql_error( $mysql_client );
        my $connection;
        if $error eq '' {
            $connection = DBDish::mysql::Connection.new(
                mysql_client => $mysql_client,
                RaiseError => $RaiseError
            );
        }
        else {
            die "DBD::mysql connection failed: $error";
        }
        return $connection;
    }
}

# warn "module DBDish::mysql.pm has loaded";

=begin pod

=head1 DESCRIPTION
# 'zavolaj' is a Native Call Interface for Rakudo/Parrot. 'DBIish' and
# 'DBDish::mysql' are Perl 6 modules that use 'zavolaj' to use the
# standard mysqlclient library.  There is a long term Parrot based
# project to develop a new, comprehensive DBI architecture for Parrot
# and Perl 6.  DBIish is not that, it is a naive rewrite of the
# similarly named Perl 5 modules.  Hence the 'Mini' part of the name.

=head1 CLASSES
The DBDish::mysql module contains the same classes and methods as every
database driver.  Therefore read the main documentation of usage in
L<doc:DBIish> and internal architecture in L<doc:DBDish>.  Below are
only notes about code unique to the DBDish::mysql implementation.

=head1 SEE ALSO
The MySQL 5.1 Reference Manual, C API.
L<http://dev.mysql.com/doc/refman/5.1/en/c-api-function-overview.html>

=end pod

