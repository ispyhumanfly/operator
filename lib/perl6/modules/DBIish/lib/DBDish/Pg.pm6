# DBDish::Pg.pm6

use NativeCall;
use DBDish;     # roles for drivers

my constant lib = 'libpq';

#module DBDish:auth<mberends>:ver<0.0.1>;

#------------ Pg library functions in alphabetical order ------------

sub PQexec (OpaquePointer $conn, str $statement)
    returns OpaquePointer
    is native(lib)
    { ... }

sub PQprepare (OpaquePointer $conn, str $statement_name, str $query, int32 $n_params, OpaquePointer $paramTypes)
    returns OpaquePointer
    is native(lib)
    { ... }

sub PQexecPrepared(
        OpaquePointer $conn,
        str $statement_name,
        int32 $n_params,
        CArray[Str] $param_values,
        CArray[int32] $param_length,
        CArray[int32] $param_formats,
        int32 $resultFormat
    )
    returns OpaquePointer
    is native(lib)
    { ... }

sub PQnparams (OpaquePointer)
    returns int32
    is native(lib)
    { ... }

sub PQdescribePrepared (OpaquePointer, str)
    returns OpaquePointer
    is native(lib)
    { ... }


sub PQresultStatus (OpaquePointer $result)
    returns int32
    is native(lib)
    { ... }

sub PQerrorMessage (OpaquePointer $conn)
    returns str
    is native(lib)
    { ... }

sub PQresultErrorMessage (OpaquePointer $result)
    returns str
    is native(lib)
    { ... }

sub PQconnectdb (str $conninfo)
    returns OpaquePointer
    is native(lib)
    { ... }

sub PQstatus (OpaquePointer $conn)
    returns int32
    is native(lib)
    { ... }

sub PQnfields (OpaquePointer $result)
    returns int32
    is native(lib)
    { ... }

sub PQntuples (OpaquePointer $result)
    returns int32
    is native(lib)
    { ... }

sub PQcmdTuples (OpaquePointer $result)
    returns str
    is native(lib)
    { ... }

sub PQgetvalue (OpaquePointer $result, int32 $row, int32 $col)
    returns str
    is native(lib)
    { ... }

sub PQgetisnull (OpaquePointer $result, int32 $row, int32 $col)
    returns int32
    is native(lib)
    { ... }

sub PQfname (OpaquePointer $result, int32 $col)
    returns str
    is native(lib)
    { ... }

sub PQclear (OpaquePointer $result)
    is native(lib)
    { ... }

sub PQfinish(OpaquePointer) 
    is native(lib)
    { ... }

sub PQftype(OpaquePointer, int32)
    is native(lib)
    returns int32
    { ... }

# from pg_type.h
constant %oid-to-type-name = (
        16  => 'Bool',  # bool
        17  => 'Buf',   # bytea
        20  => 'Int',   # int8
        21  => 'Int',   # int2
        23  => 'Int',   # int4
        25  => 'Str',   # text
       700  => 'Num',   # float4
       701  => 'Num',   # float8
      1000  => 'Bool',  # _bool
      1001  => 'Buf',   # _bytea
      1005  => 'Int',   # _int2
      1009  => 'Str',   # _text
      1015  => 'Str',   # _varchar
      1021  => 'Num',   # _float4
      1022  => 'Num',   # _float8
      1043  => 'Str',   # varchar
      1700  => 'Real',  # numeric
      2950  => 'Str',   # uuid
      2951  => 'Str',   # _uuid


).hash;

constant CONNECTION_OK     = 0;
constant CONNECTION_BAD    = 1;

constant PGRES_EMPTY_QUERY = 0;
constant PGRES_COMMAND_OK  = 1;
constant PGRES_TUPLES_OK   = 2;
constant PGRES_COPY_OUT    = 3;
constant PGRES_COPY_IN     = 4;

sub status-is-ok($status) { $status ~~ (0..4) }

#-----------------------------------------------------------------------

my grammar PgTokenizer {
    token double_quote_normal { <-[\\"]>+ }
    token double_quote_escape { [\\ . ]+ }
    token double_quote {
        \"
        [
            | <.double_quote_normal>
            | <.double_quote_escape>
        ]*
        \"
    }
    token single_quote_normal { <-['\\]>+ }
    token single_quote_escape { [ \'\' | \\ . ]+ }
    token single_quote {
        \'
        [
            | <.single_quote_normal>
            | <.single_quote_escape>
        ]*
        \'
    }
    token placeholder { '?' }
    token normal { <-[?"']>+ }

    token TOP {
        ^
        (
            | <normal>
            | <placeholder>
            | <single_quote>
            | <double_quote>
        )*
        $
    }
}

my class PgTokenizer::Actions {
    has $.counter = 0;
    method single_quote($/) { make $/.Str }
    method double_quote($/) { make $/.Str }
    method placeholder($/)  { make '$' ~ ++$!counter }
    method normal($/)       { make $/.Str }
    method TOP($/) {
        make $0.flatmap({.values[0].ast}).join;
    }
}


class DBDish::Pg::StatementHandle does DBDish::StatementHandle {
    has $!pg_conn;
    has Str $!statement_name;
    has $!statement;
    has $!param_count;
    has $.dbh;
    has $!result;
    has $!affected_rows;
    has @!column_names;
    has Int $!row_count;
    has $!field_count;
    has $!current_row = 0;

    method !handle-errors {
        my $status = PQresultStatus($!result);
        if status-is-ok($status) {
            self!reset_errstr;
            return True;
        }
        else {
            self!set_errstr(PQresultErrorMessage($!result));
            die self.errstr if $.RaiseError;
            return Nil;
        }
    }

    method !munge_statement {
        my $count = 0;
        $!statement.subst(:g, '?', { '$' ~ ++$count});
    }

    submethod BUILD(:$!statement, :$!pg_conn, :$!statement_name, :$!param_count,
           :$!dbh) {
    }
    method execute(*@params is copy) {
        $!current_row = 0;
        die "Wrong number of arguments to method execute: got @params.elems(), expected $!param_count" if @params != $!param_count;
        my @param_values := CArray[Str].new;
        for @params.kv -> $k, $v {
            @param_values[$k] = $v.Str;
        }

        $!result = PQexecPrepared($!pg_conn, $!statement_name, @params.elems,
                @param_values,
                OpaquePointer, # ParamLengths, NULL pointer == all text
                OpaquePointer, # ParamFormats, NULL pointer == all text
                0,             # Resultformat, 0 == text
        );

        self!handle-errors;
        $!row_count = PQntuples($!result);

        my $rows = self.rows;
        return ($rows == 0) ?? "0E0" !! $rows;
    }

    # do() and execute() return the number of affected rows directly or:
    # rows() is called on the statement handle $sth.
    method rows() {
        unless defined $!affected_rows {
            $!affected_rows = PQcmdTuples($!result);

            self!handle-errors;
        }

        if defined $!affected_rows {
            return +$!affected_rows;
        }
    }

    method fetchrow() {
        my @row_array;
        return () if $!current_row >= $!row_count;

        unless defined $!field_count {
            $!field_count = PQnfields($!result);
        }

        if defined $!result {
            self!reset_errstr;

            for ^$!field_count {
                my $res := PQgetvalue($!result, $!current_row, $_);
                if $res eq '' {
                    $res := Str if PQgetisnull($!result, $!current_row, $_)
                }
                @row_array.push($res)
            }
            $!current_row++;
            self!handle-errors;

            if ! @row_array { self.finish; }
        }
        return @row_array;
    }

    method column_names {
        $!field_count = PQnfields($!result);
        unless @!column_names {
            for ^$!field_count {
                my $column_name = PQfname($!result, $_);
                @!column_names.push($column_name);
            }
        }
        @!column_names
    }

    # for debugging only so far
    method column_oids {
        $!field_count = PQnfields($!result);
        my @res;
        for ^$!field_count {
            @res.push: PQftype($!result, $_);
        }
        @res;
    }

    method fetchall_hashref(Str $key) {
        my %results;

        return () if $!current_row >= $!row_count;

        while my $row = self.fetchrow_hashref {
            %results{$row{$key}} = $row;
        }

        my $results_ref = %results;
        return $results_ref;
    }

    method finish() {
        if defined($!result) {
            PQclear($!result);
            $!result       = Any;
            @!column_names = ();
        }
        return Bool::True;
    }

    method !get_row {
        my @data;
        for ^$!field_count {
            @data.push(PQgetvalue($!result, $!current_row, $_));
        }
        $!current_row++;

        return @data;
    }
}

class DBDish::Pg::Connection does DBDish::Connection {
    has $!pg_conn;
    has $.AutoCommit is rw = 1;
    has $.in_transaction is rw;
    submethod BUILD(:$!pg_conn, :$!AutoCommit, :$!in_transaction) { }

    method prepare(Str $statement, $attr?) {
        state $statement_postfix = 0;
        my $statement_name = join '_', 'pg', $*PID, $statement_postfix++;
        my $munged = DBDish::Pg::pg-replace-placeholder($statement);
        my $result = PQprepare(
                $!pg_conn,
                $statement_name,
                $munged,
                0,
                OpaquePointer
        );
        my $status = PQresultStatus($result);
        unless status-is-ok($status) {
            self!set_errstr(PQresultErrorMessage($result));
            die self.errstr if $.RaiseError;
            return Nil;
        }
        my $info = PQdescribePrepared($!pg_conn, $statement_name);
        my $param_count = PQnparams($info);

        my $statement_handle = DBDish::Pg::StatementHandle.bless(
            :$!pg_conn,
            :$statement,
            :$.RaiseError,
            :dbh(self),
            :$statement_name,
            :$result,
            :$param_count,
        );
        return $statement_handle;
    }

    method do(Str $statement, *@bind is copy) {
        my $sth = self.prepare($statement);
        $sth.execute(@bind);
        my $rows = $sth.rows;
        return ($rows == 0) ?? "0E0" !! $rows;
    }

    method selectrow_arrayref(Str $statement, $attr?, *@bind is copy) {
        my $sth = self.prepare($statement, $attr);
        $sth.execute(@bind);
        return $sth.fetchrow_arrayref;
    }

    method selectrow_hashref(Str $statement, $attr?, *@bind is copy) {
        my $sth = self.prepare($statement, $attr);
        $sth.execute(@bind);
        return $sth.fetchrow_hashref;
    }

    method selectall_arrayref(Str $statement, $attr?, *@bind is copy) {
        my $sth = self.prepare($statement, $attr);
        $sth.execute(@bind);
        return $sth.fetchall_arrayref;
    }

    method selectall_hashref(Str $statement, Str $key, $attr?, *@bind is copy) {
        my $sth = self.prepare($statement, $attr);
        $sth.execute(@bind);
        return $sth.fetchall_hashref($key);
    }

    method selectcol_arrayref(Str $statement, $attr?, *@bind is copy) {
        my @results;

        my $sth = self.prepare($statement, $attr);
        $sth.execute(@bind);
        while (my $row = $sth.fetchrow_arrayref) {
            @results.push($row[0]);
        }

        my $aref = @results;
        return $aref;
    }

    method commit {
        if $!AutoCommit {
            warn "Commit ineffective while AutoCommit is on";
            return;
        };
        PQexec($!pg_conn, "COMMIT");
        $.in_transaction = 0;
    }

    method rollback {
        if $!AutoCommit {
            warn "Rollback ineffective while AutoCommit is on";
            return;
        };
        PQexec($!pg_conn, "ROLLBACK");
        $.in_transaction = 0;
    }

    method ping {
        PQstatus($!pg_conn) == CONNECTION_OK
    }

    method disconnect() {
        PQfinish($!pg_conn);
        True;
    }
}

class DBDish::Pg:auth<mberends>:ver<0.0.1> {

    our sub pg-replace-placeholder(Str $query) is export {
        PgTokenizer.parse($query, :actions(PgTokenizer::Actions.new))
            and $/.ast;
    }

    has $.Version = 0.01;
    has $!errstr;
    method !errstr() is rw { $!errstr }
    method errstr() { $!errstr }

    sub quote-and-escape($s) {
        "'" ~ $s.trans([q{'}, q{\\]}] => [q{\\\'}, q{\\\\}])
            ~ "'"
    }

#------------------ methods to be called from DBIish ------------------
    method connect(*%params) {
        my %keymap =
            database => 'dbname',
            ;
        my @connection_parameters = gather for %params.kv -> $key, $value {
            # Internal parameter, not for PostgreSQL usage.
            next if $key ~~ / <-lower> /;
            my $translated = %keymap{ $key } // $key;
            take "$translated={quote-and-escape $value}"
        }
        my $conninfo = ~@connection_parameters;
        my $pg_conn = PQconnectdb($conninfo);
        my $status = PQstatus($pg_conn);
        my $connection;
        if $status eq CONNECTION_OK {
            $connection = DBDish::Pg::Connection.bless(
                :$pg_conn,
                :RaiseError(%params<RaiseError>),
            );
        }
        else {
            $!errstr = PQerrorMessage($pg_conn);
            if %params<RaiseError> { die $!errstr; }
        }
        return $connection;
    }
}

=begin pod

=head1 DESCRIPTION
# 'zavolaj' is a Native Call Interface for Rakudo/Parrot. 'DBIish' and
# 'DBDish::Pg' are Perl 6 modules that use 'zavolaj' to use the
# standard libpq library.  There is a long term Parrot based
# project to develop a new, comprehensive DBI architecture for Parrot
# and Perl 6.  DBIish is not that, it is a naive rewrite of the
# similarly named Perl 5 modules.  Hence the 'Mini' part of the name.

=head1 CLASSES
The DBDish::Pg module contains the same classes and methods as every
database driver.  Therefore read the main documentation of usage in
L<doc:DBIish> and internal architecture in L<doc:DBDish>.  Below are
only notes about code unique to the DBDish::Pg implementation.

=head1 SEE ALSO
The Postgres 8.4 Documentation, C Library.
L<http://www.postgresql.org/docs/8.4/static/libpq.html>

=end pod

