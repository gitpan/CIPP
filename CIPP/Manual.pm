=head1 NAME

CIPP - Reference Manual

=head1 SYNOPSIS

  perldoc CIPP::Manual

=head1 DESCRIPTION

This is the reference manual for CIPP, the powerful preprocessor
language for embedding Perl and SQL in HTML. This documentation
module is part of the CIPP distribution available on CPAN.

The manual describes all CIPP commands in alphabetical order.
Each reference contains syntax notation, textual description
and examples for each command.

This document is a excerpt from the full CIPP documentation which
is available as PDF format. You can download the PDF document
from CPAN:

  $CPAN/modules/by-authors/id/J/JR/JRED/CIPP-DOC-x.xx.tar.gz

The conversion of the FrameMaker source document to the POD
format is done automatically. Due to this the layout maybe slightly
messed up in some sections, but everything should be readable
nevertheless. If you don't like this please refer to the PDF
document which has a really nice layout.

=head1 QUICK FIND A COMMAND DESCRIPTION

If your perldoc is using 'less' for paging, it is easy to jump
to a particular command description.

E.g. if you want to read the E<lt>?FOO> section, simply type this.

  /COMMAND...FOO

=head1 LIST OF CIPP COMMANDS

This is a alphabetical list of all CIPP commands with a
short description, divided into sections of command types.

=head2 Variables and Scoping

=over 8

=item BLOCK

Creation of a block context to limit the scope of private variables

=item MY

Declaring a private (block local) variable

=item VAR

Definition of a variable

=back

=head2 Control Structures

=over 8

=item DO

Loop with condition check after first iteration

=item ELSE

Alternative execution of a block

=item ELSIF

Subsequent conditional execution

=item FOREACH

Loop iterating with a variable over a list

=item IF

Conditional execution of a block

=item PERL

Insertion of pure Perl code

=item SUB

Definition of a Perl subroutine

=item WHILE

Loop with condition check before first iteration

=back

=head2 Import

=over 8

=item CONFIG

Import a config file in your program

=item INCLUDE

Insertion of a CIPP Include file in the actual CIPP code

=item LIB

Import a Perl module in your program

=back

=head2 Exception Handling

=over 8

=item CATCH

Execution of a block if a particular exception was thrown in a preceding TRY block.

=item LOG

Write a entry in a logfile.

=item THROW

Explicite creation of an exception.

=item TRY

Secured execution of a block. Any exceptions thrown in the encapsulated block are caught.

=back

=head2 SQL

=over 8

=item AUTOCOMMIT

Control of transaction behaviour

=item COMMIT

Commit a transaction

=item DBQUOTE

Quoting of a variable for usage in a SQL statement

=item GETDBHANDLE

Returns the internal DBI database handle

=item ROLLBACK

Rollback a transaction

=item SQL

Execution of a SQL statement

=back

=head2 URL- and Form Handling

=over 8

=item GETURL

Creation of a CIPP object URL

=item HIDDENFIELDS

Producing a number of hidden formular fields

=item HTMLQUOTE

HTML encoding of a variable

=item URLENCODE

URL encoding of a variable

=back

=head2 HTML Tag Replacements

=over 8

=item A

Replaces <A> tag

=item FORM

Replaces <FORM> tag

=item IMG

Replaces <IMG> tag

=item INPUT

Replaces <INPUT> tag

=item TEXTAREA

Replaces <TEXTAREA> tag

=back

=head2 Interface

=over 8

=item GETPARAM

Recieving a non declared CGI input parameter

=item GETPARAMLIST

Returns a list of all CGI input parameter names

=item INCINTERFACE

Declaration of a interface for CIPP Include

=item INTERFACE

Declaration of a CGI interface for a CIPP program

=item SAVEFILE

Storing a client side upload file

=back

=head2 Apache

=over 8

=item APGETREQUEST

Returns the internal Apache request object

=item APREDIRECT

Redirects to another URL internally

=back

=head2 Preprocessor

=over 8

=item AUTOPRINT

Controls automatic output of HTML code

=back

=head1 COMMAND E<lt>?A>

=over 8

=item B<Type>

HTML Tag Replacement

=item B<Syntax>

 <?A HREF=hyperlinked_object_name[#anchor]
     [ additional_<A>_parameters ... ] >
 ...
 <?/A>

=item B<Description>

This command replaces the E<lt>A> HTML tag. You will need this in a new.spirit environment to set a link to a CIPP CGI or HTML object.

=item B<Parameter>

=item B<     HREF>

This parameter takes the name of the hyperlinked object. You may optionally add an anchor (which should be defined using E<lt>A NAME> in the referred page) using the # character as a delimiter.

This paremeter is expected as an URL in CGI::CIPP or Apache::CIPP environments and in dotC<-s>eparated object notation in a new.spirit environment.

=item B<     additional_A_parameters>

All additional parameters are taken into the generated E<lt>A> tag.

=item B<Example>

Textual link to 'MSG.Main', in a new.spirit environment.

  <?A HREF="MSG.Main">Back to the main menu<?/A>

Image link to '/main/menu.cgi', in a CGI::CIPP or Apache::CIPP environment:

  <?A HREF="/main/menu.cgi">
  <?IMG SRC="/images/logo.gif" BORDER=0>
  <?/A>

=back

=head1 COMMAND E<lt>?APGETREQUEST>

=over 8

=item B<Type>

Apache

=item B<Syntax>

 <?APGETREQUEST [ MY ] VAR=request_variable >

=item B<Description>

This command is only working if CIPP is used as an Apache module.

It returns the internal Apache request object, so you can use Apache specific features.

=item B<Parameter>

=item B<     VAR>

This is the variable where the request object will be stored.

=item B<     MY>

If you set the MY switch, the created variable will be declared using 'my'. Its scope reaches to the end of the block which surrounds the APGETREQUEST command.

=item B<Example>

The Apache request object will be stored in the implicitely declared variable $ar.

  <?APGETREQUEST MY VAR=$ar>

=back

=head1 COMMAND E<lt>?APREDIRECT>

=over 8

=item B<Type>

Apache

=item B<Syntax>

 <?APREDIRECT URL=new_URL >

=item B<Description>

This command is only working if CIPP is used as an Apache module.

It results in an internal Apache redirect. That means, the new url will be 'executed' without notifying the client about this.

=item B<Parameter>

=item B<     URL>

This expression is used for the new URL.

=item B<Note:>

The program which uses E<lt>?APREDIRECT> should not produce any output, otherwise this may confuse the webserver or the client, if more then one HTTP header is sent. So you should use E<lt>?AUTOPRINT OFF> at the top of the program to circumvent that.

=item B<Example>

This commands redirect internally to the homepage of the corresponding website:

  <?AUTOPRINT OFF>
  <?APREDIRECT URL="/">

=back

=head1 COMMAND E<lt>?AUTOCOMMIT>

=over 8

=item B<Type>

SQL

=item B<Syntax>

 <?AUTOCOMMIT ( ON | OFF )
              [ DB=database_name ]
              [ THROW=exception ] >

=item B<Description>

The E<lt>?AUTOCOMMIT> command corresponds directly to the underlying DBI AutoCommit mechanism.

If AutoCommit is activated each SQL statement will implicitely be executed in its own transaction. Think of a E<lt>?COMMT> after each statement. Explicite use of E<lt>?COMMIT> or E<lt>?ROLLBACK> is forbidden in AutoCommit mode.

If AutoCommit is deactivated you have to call E<lt>?COMMIT> or E<lt>?ROLLBACK> yourself. CIPP will rollback any uncommited open transactions at the end of the program.

=item B<Parameter>

=item B<     ON | OFF>

Switch AutoCommit modus either on or off.

=item B<     DB>

This is the CIPP internal name of the database for this command. In CGI::CIPP or Apache::CIPP environment this name has to be defined in the appropriate global configuration. In a new.spirit environment this is the name of the database configuration object in dotC<-s>eparated notation.

If DB is ommited the project default database is used.

=item B<     THROW>

With this parameter you can provide a user defined exception which should be thrown on failure. The default exception thrown by this statement is autocommit.

If the underlying database is not capable of transactions (e.g. MySQL) setting AutoCommit to ON will throw an exception.

=item B<Example>

Switch AutoCommit on for the database 'foo'.

  <?AUTOCOMMIT ON DB="foo">

Switch AutoCommit off for the database 'bar' and throw the user defined exception 'myautocommit' on failure.

  <?AUTOCOMMIT OFF DB="bar" THROW="myautocommit">

=back

=head1 COMMAND E<lt>?AUTOPRINT>

=over 8

=item B<Type>

Preprocessor

=item B<Syntax>

 <?AUTOPRINT OFF>

=item B<Description>

With the E<lt>?AUTOPRINT OFF> command the preprocessor can be advised to suppress the generation of print statements for non CIPP blocks. The default setting is ON and it is only possible to switch it OFF and not the other way around.

=item B<Parameter>

=item B<     OFF>

Automatic generation of print statements for non CIPP blocks will be deactivated.

=item B<Note>

Use this with care. Because this is a preprocessor command it will produce strange results if you use this in CIPP Includes.

Instead you should use this command at the very top of your program file. CIPP will not generate any HTTP headers for you, if you use E<lt>?AUTOPRINT OFF>, so you have to do this on your own.

=item B<Example>

This program sends a GIF image to the client, after generating the proper HTTP header. (For another example, see <?APREDIRECT>)

  <?AUTOPRINT OFF>
These lines will never be printed, they are fully ignored!!!

  <?PERL>
    my $file = "/tmp/image.gif";
    my $size = -s $file;

    print "Content-type: image/gif\n";
    print "Content-length: $size\n\n";

    open (GIF, $file) or die "can't open $file";
    while (<GIF>) {
      print;
    }
    close GIF;
  <?/PERL>

=back

=head1 COMMAND E<lt>?BLOCK>

=over 8

=item B<Type>

Variables and Scoping

=item B<Syntax>

 <?BLOCK>
 ...
 <?/BLOCK>

=item B<Description>

Use the E<lt>?BLOCK> command to divide your program into logical blocks to control variable scoping. Variables declared with E<lt>?MY> inside a block are not valid outside.

=item B<Example>

The variable $example does not exist beyond the block.

  <?BLOCK>
    <?MY $example>
    $example is known.
  <?/BLOCK>

$example does not exist here. This will

result in a Perl compiler error, because

$example is not declared here.

=back

=head1 COMMAND E<lt>?CATCH>

=over 8

=item B<Type>

Exception Handling

=item B<Syntax>

 <?CATCH [ THROW=exception ]
         [ MY ]
         [ EXCVAR=variable_for_exception ]
         [ MSGVAR=variable_for_error_message ] >
 ...
 <?/CATCH>

=item B<Description>

Typically a E<lt>?CATCH> block follows after a E<lt>?TRY> block. You can process one particular or just any exception with the E<lt>?CATCH> block.

E<lt>?CATCH> and E<lt>?TRY> has to be placed inside the same block.

See the description of E<lt>?TRY> for details about the CIPP exception handling mechanism.

=item B<Parameter>

=item B<     THROW>

If this parameter is omitted, all exceptions will be processed here. Otherwise the E<lt>?CATCH> block is executed only if the appropriate exception was thrown.

=item B<     EXCVAR>

Names the variable, where the exception identifier should be stored in. Usefull if you use E<lt>?CATCH> for a generic exception handler and omitted the THROW parameter.

=item B<     MSGVAR>

Name the variable, where the error message should be stored in.

=item B<     MY>

If you set the MY switch the created variable will be declared using 'my'. Its scope reaches to the end of the block which surrounds the E<lt>?CATCH> command.

=item B<Example>

We try to insert a row into a database table, which has a primary key defined, and commit the transcation. We catch two exceptions: the possible primary key constraint violation and a possible commit exception, maybe the database is not capable of transactions.

  <?TRY>
    <?SQL SQL="insert into persons
              (firstname, lastname)
               values ('John', 'Doe')"><?/SQL>
    <?COMMIT>
  <?/TRY>

  <?CATCH THROW=sql MY MSGVAR=$message>
    <?LOG MSG="Can't insert data: $message"
          TYPE="database">
  <?/CATCH>

  <?CATCH THROW=commit MSGVAR=$message>
    <?LOG MSG="COMMIT rejected: $message"
          TYPE="database">
  <?/CATCH>

=back

=head1 COMMAND E<lt>?COMMIT>

=over 8

=item B<Type>

SQL

=item B<Syntax>

 <?COMMIT [ DB=database_name ]
          [ THROW=exception ] >

=item B<Description>

The E<lt>?COMMIT> command concludes the actual transaction and makes all changes to the database permanent.

Using E<lt>?COMMIT> in E<lt>?AUTOCOMMIT ON> mode is not possible.

If you are not in E<lt>?AUTOCOMMIT ON> mode a transaction begins with the first SQL statement and end either with a E<lt>?COMMIT> or E<lt>?ROLLBACK> command.

=item B<Parameter>

=item B<     DB>

This is the CIPP internal name of the database for this command. In CGI::CIPP or Apache::CIPP environment this name has to be defined in the appropriate global configuration. In a new.spirit environment this is the name of the database configuration object in dotC<-s>eparated notation.

If DB is ommited the project default database is used.

=item B<     THROW>

With this parameter you can provide a user defined exception which should be thrown on failure. The default exception thrown by this statement is commit.

If the underlying database is not capable of transactions (e.g. MySQL) execution of this command will throw an exception.

=item B<Example>

We insert a row into a database table and commit the change immediately. We throw a user defined exeption, if the commit fails. So be safe we first disable AutoCommiting.

  <?AUTOCOMMIT OFF>
  <?SQL SQL="insert into foo (num, str)
             values (42, 'bar');">
  <?/SQL>
  <?COMMIT THROW="COMMIT_Exception">

=back

=head1 COMMAND E<lt>?CONFIG>

=over 8

=item B<Type>

Import

=item B<Syntax>

 <?CONFIG NAME=config_file
          [ RUNTIME ] [ NOCACHE ]
          [ THROW=exception ] >

=item B<Description>

The E<lt>?CONFIG> command reads a config file. This is done via a mechanism similar to Perl's require, so the config file has to be pure Perl code defining global variables.

E<lt>?CONFIG> ensures a proper load of the configuration file even in persistent Perl environments.

In contrast to "require" E<lt>?CONFIG>  will reload a config file when the file was altered on disk. Otherwise the file will only be loaded once.

=item B<Parameter>

=item B<     NAME>

This is the name of the config file, expected as an URL in CGI::CIPP or Apache::CIPP environments and in dotC<-s>eparated object notation in a new.spirit environment.

=item B<     RUNTIME>

This switch makes sense only in a new.spirit environment. If you set it the NAME parameter will be resolved at runtime, so it can contain variables. new.spirit will not check the existance of the file in this case. Normally you'll get a CIPP error message, if the adressed file does not exist.

In CGI::CIPP and Apache::CIPP environments the NAME parameter will always be resolved at runtime.

=item B<     NOCACHE>

This switch is useful in persistant Perl environments. It forces E<lt>?CONFIG> to read the config file even if it did not change on disk. You'll need this if your config file does some calculations based on the request environment, e.g. if the value of some variables depends on the clients user agent.

=item B<     THROW>

With this parameter you can provide a user defined exception to be thrown on failure. The default exception thrown by this statement is config.

An exception will be thrown, if the config file does not exist or is not readable.

=item B<Example>

Load of the configuration file "/lib/general.conf", with disabled cache, used in CGI::CIPP or Apache::CIPP environment:

  <?CONFIG NAME="/lib/general.conf" NOCACHE>

Load of the configuration file object x.custom.general in a new.spirit environment:

  <?CONFIG NAME="x.custom.general">

Load of a config file with a name determined at runtime, in a new.spirit environment, throwing "myconfig" on failure:

  <?CONFIG NAME="$config_file" RUNTIME
           THROW="myconfig">

=back

=head1 COMMAND E<lt>?DBQUOTE>

=over 8

=item B<Type>

SQL

=item B<Syntax>

 <?DBQUOTE VAR=variable
           [ MY ]
           [ DBVAR=quoted_result_variable ]
           [ DB=database_name ] >

=item B<Description>

E<lt>?SQL> (and DBI) has a nice way of quoting parameters to SQL statements (called parameter binding). Usage of that mechanism is generally recommended (see E<lt>?SQL> for details). However if you need to construct your own SQL statement, E<lt>?DBQUOTE>  will let you do so.

E<lt>?DBQUOTE>  will generate the string representation of the given scalar variable as fit for an SQL statement. That is, it takes care of quoting special characteres.

=item B<Parameter>

=item B<     VAR>

This is the scalar variable containing the parameter you want to be quoted.

=item B<     DBVAR>

This optional parameters takes the variable where the quoted content should be stored. The surrounding ' characters are part of the result, if the variable is not undef. A value of undef will result in NULL (without the surrounding '), so the quoted variable can be placed directly in a SQL statement.

If you ommit DBVAR, the name of the target variable is computed by placing the prefix 'db_' in front of the VAR name.

=item B<     MY>

If you set the MY switch the created variable will be declared using 'my'. Its scope reaches to the end of the block which surrounds the E<lt>?DBQUOTE> command.

=item B<     DB>

This is the CIPP internal name of the database for this command. In CGI::CIPP or Apache::CIPP environment this name has to be defined in the appropriate global configuration. In a new.spirit environment this is the name of the database configuration object in dotC<-s>eparated notation.

If DB is ommited the project default database is used.

=item B<Example>

This quotes the variable $name, the result will be stored in the just declared variable $db_name.

  <?DBQUOTE MY VAR="$name">

This quotes $name, but stores the result in the variable $quoted_name.

  <?DBQUOTE VAR="$name" MY DBVAR="$quoted_name">

The quoted variable can be used in a SQL statement this way:

  <?SQL SQL="insert into persons (name)
             values ( $quoted_name )">

=back

=head1 COMMAND E<lt>?DO>

=over 8

=item B<Type>

Control Structure

=item B<Syntax>

 <?DO>
 ...
 <?/DO COND=condition >

=item B<Description>

The E<lt>?DO> block repeats executing the contained code as long as the condition evaluates true. The condition is checked afterwards. That means that the block will always be executed at least once.

=item B<Parameter>

=item B<     COND>

This takes a Perl condition. As long as this condition is true the E<lt>?DO> block will be repeated.

=item B<Example>

Print  "Hello World" $n times. (note: for n=0 and n=1 you get the same result)

  <?DO>
    Hello World<BR>
  <?/DO COND="--$n > 0">

=back

=head1 COMMAND E<lt>?ELSE>

=over 8

=item B<Type>

Control Structure

=item B<Syntax>

 <?ELSE>

=item B<Description>

E<lt>?ELSE> closes an open E<lt>?IF> or E<lt>?ELSIF> conditional block and opens a new block (which is later terminated by E<lt>?/IF>). The block is only executed if the condition of the preceding block was evaluated and failed.

E<lt>?MY> variables are only visible inside this block.

(Or short: it works as you would expect.)

=item B<Example>

Only Larry gets a personal greeting message:

  <?IF COND="$name eq 'Larry'">
    Hi Larry, you're welcome!
  <?ELSE>
    Hi Stranger!
  <?/IF>

=back

=head1 COMMAND E<lt>?ELSIF>

=over 8

=item B<Type>

Control Structure

=item B<Syntax>

 <?ELSIF COND=condition >

=item B<Description>

E<lt>?ELSIF> closes an open E<lt>?IF> or E<lt>?ELSIF> conditional block and opens a new block. The condition is only evaluated if the condition of the preceding block was evaluated and failed.

E<lt>?MY> variables are only visible inside this block.

(Or short: it works as you would expect.)

=item B<Parameter>

=item B<     COND>

Takes the Perl condition.

=item B<Example>

Larry and Linus get personal greeting messages:

  <?IF COND="$name eq 'Larry'">
    Hi Larry, you're welcome!
  <?ELSIF COND="$name eq 'Linus'">
    Hi Linus, you're velkomma!
  <?ELSE>
    Hi Stranger!
  <?/IF>

=back

=head1 COMMAND E<lt>?FOREACH>

=over 8

=item B<Type>

Control Structure

=item B<Syntax>

 <?FOREACH [ MY ] VAR=running_variable
           LIST=perl_list >
 ...
 <?/FOREACH>
 

=item B<Description>

E<lt>?FOREACH> corresponds directly the Perl foreach command. The running variable will iterate of the list, executing the enclosed block for each value of the list.

=item B<Parameter>

=item B<     VAR>

This is the scalar running variable.

=item B<     LIST>

You can write any Perl list here, e.g. using the bracket notation or pass a array variable using the @ notation.

=item B<     MY>

If you set the MY switch the created running variable will be declared using 'my'. Its scope reaches to the end of the block which surrounds the E<lt>?FOREACH> command.

Note: this is a slightly different behaviour compared to a Perl "foreach my $var (@list)" command, where the running variable $var is valid only inside of the foreach block.

=item B<Example>

Counting up to 'three':

  <?FOREACH MY VAR="$cnt"
            LIST="('one', 'two', 'three')">
    $cnt
  <?/FOREACH>

=back

=head1 COMMAND E<lt>?FORM>

=over 8

=item B<Type>

HTML Tag Replacement

=item B<Syntax>

 <?FORM ACTION=cgi_file
        [ additional_<FORM>_parameters ... ] >
 ...
 <?/FORM>

=item B<Description>

E<lt>?FORM> generates a HTML E<lt>FORM> tag, setting the ACTION option to the appropriate URL. The request METHOD defaults to POST if no other value is given.

=item B<Parameter>

=item B<     ACTION>

This is the name of the form target CGI program, expected as an URL in CGI::CIPP or Apache::CIPP environments and in dotC<-s>eparated object notation in a new.spirit environment.

=item B<     additional_FORM_parameters>

All additional parameters are taken over without changes into the produced E<lt>FORM> tag. If you ommit the METHOD parameter it will default to POST.

=item B<Example>

Creating a named form with a submit button, pointing to the CGI object "x.login.start", in a new.spirit environment:

  <?FORM ACTION="x.login.start" NAME="myform">
  <?INPUT TYPE=SUBMIT VALUE=" Start ">
  <?/FORM>

Creating a similar form, but the action is written as an URL because we are in CGI::CIPP or Apache::CIPP environment:

  <?FORM ACTION="/login/start.cgi" NAME="myform">
  <?INPUT TYPE=SUBMIT VALUE=" Start ">
  <?/FORM>

=back

=head1 COMMAND E<lt>?GETDBHANDLE>

=over 8

=item B<Type>

SQL

=item B<Syntax>

 <?GETDBHANDLE [ DB=database_name ] [ MY ]
               VAR=handle_variable >

=item B<Description>

This command returns a reference to the internal Perl database handle, which is the object references returned by DBI->connect.

With this handle you are able to perform DBI specific functions which are currently not directly available through CIPP.

=item B<Parameter>

=item B<     VAR>

This is the variable where the database handle will be stored.

=item B<     MY>

If you set the MY switch the created variable will be declared using 'my'. Its scope reaches to the end of the block which surrounds the E<lt>?GETDBHANDLE> command.

=item B<     DB>

This is the CIPP internal name of the database for this command. In CGI::CIPP or Apache::CIPP environment this name has to be defined in the appropriate global configuration. In a new.spirit environment this is the name of the database configuration object in dotC<-s>eparated notation.

If DB is ommited the project default database is used.

=item B<Example>

We get the database handle for the database object 'x.Oracle' in a new.spirit environment and perform a select query using this handle.

Ok, you simply can do this with the <?SQL> command, but now you can see how much work is done for you through CIPP :)

  <?GETDBHANDLE DB="MSG.Oracle" MY VAR="$dbh">

  <?PERL>
    my $sth = $dbh->prepare ( qq{
        select n,s from TEST_table
        where n between 10 and 20
    });
    die "my_sql\t$DBI::errstr" if $DBI::errstr;

    $sth->execute;
    die "my_sql\t$DBI::errstr" if $DBI::errstr;

    my ($n, $s);
    while ( ($n, $s) = $sth->fetchrow ) {
      print "n=$n s=$s<BR>\n";
    }
    $sth->finish;
    die "my_sql\t$DBI::errstr" if $DBI::errstr;

  <?/PERL>

=back

=head1 COMMAND E<lt>?GETPARAM>

=over 8

=item B<Type>

Interfaces

=item B<Syntax>

 <?GETPARAM NAME=parameter_name
            [ MY ] [ VAR=content_variable ] >

=item B<Description>

With this command you can explicitely get a CGI parameter. This is useful if your CGI program uses dynamically generated parameter names, so you are not able to use E<lt>?INTERFACE> for them.

Refer to E<lt>?INTERFACE> to see how easy it is to handle standard CGI input parameters.

=item B<Parameter>

=item B<     NAME>

Identifier of the CGI input parameter

=item B<     VAR>

This is the variable where the content of the CGI parameter will be stored. This can be either a scalar variable (indicated through a $ sign) or an array variable (indicated through a @ sign).

=item B<     MY>

If you set the MY switch the created variable will be declared using 'my'. Its scope reaches to the end of the block which surrounds the E<lt>?GETPARAM> command.

=item B<Example>

We recieve two parameters, one staticly named parameter and one scalar parameter, which has a dynamic generated identifier.

  <?GETPARAM NAME="listparam" MY VAR="@list">
  <?GETPARAM NAME="scalar$name" MY VAR="$scalar">

=back

=head1 COMMAND E<lt>?GETPARAMLIST>

=over 8

=item B<Type>

Interfaces

=item B<Syntax>

 <?GETPARAMLIST [ MY ] VAR=variable >

=item B<Description>

This command returns a list containing the identifiers of all CGI input parameters.

=item B<Parameter>

=item B<     VAR>

This is the variable where the identifiers of all CGI input parameters will be stored in. It must be an array variable, indicated through a @ sign.

=item B<     MY>

If you set the MY switch the created list variable will be declared using 'my'. Its scope reaches to the end of the block which surrounds the E<lt>?GETPARAMLIST> command.

=item B<Example>

The list of all CGI input parameter identifiers will be stored into the array variable @input_param_names.

  <?GETPARAMLIST MY VAR="@input_param_names">

=back

=head1 COMMAND E<lt>?GETURL>

=over 8

=item B<Type>

URL and Form Handling

=item B<Syntax>

 <?GETURL NAME=object_file
          [ MY ] URLVAR=url_variable
          [ RUNTIME ] [ THROW=exception ] >
          [ PARAMS=parameters_variables ]
          [ PAR_1=value_1 ... PAR_n=value_n ] >

=item B<Description>

This command returns a URL, optionally with parameters. In a new.spirit environment you use this to resolve the dotC<-s>eparated object name to a real life URL.

In CGI::CIPP and Apache::CIPP environments this is not necessary, because you work always with real URLs. Nevertheless it also useful there, because its powerfull possibilities of generating parmeterized URLs.

=item B<Parameter>

=item B<     NAME>

This is the name of the specific file, expected as an URL in CGI::CIPP or Apache::CIPP environments and in dotC<-s>eparated object notation in a new.spirit environment.

=item B<     URLVAR>

This is the scalar variable where the generated URL will be stored in.

=item B<     MY>

If you set the MY switch the created variable will be declared using 'my'. Its scope reaches to the end of the block which surrounds the E<lt>?GETURL> command.

=item B<     RUNTIME>

This switch makes only sense in a new.spirit environment. The NAME parameter will be resolved at runtime, so it can contain variables. CIPP will not check the existance of the file in this case. Normally you get a CIPP error message, if the adressed file does not exist.

In CGI::CIPP and Apache::CIPP environments the NAME parameter will always be resolved at runtime.

=item B<     THROW>

With this parameter you can define the exception to be thrown on failure. The default exception thrown by this statement is geturl.

An exception will be thrown, if the adressed file does not exist.

=item B<     PARAMS>

This takes a comma separated list of parameters, which will be encoded and added to the generated URL. You may pass scalar variables (indicated through the $ sign) and also array variables (indicated through the @ sign).

With the PARAMS option you can only pass parameters whose values are stored in variables with the same name (where case is significant). The variables listed in PARAMS will be treated case sensitive.

=item B<     PAR_1..PAR_n>

Any additional parameters to E<lt>?GETURL> are interpreted as named parameters for the URL.  You can pass scalar and array values this way (using $ and @). Variables passed this way are seen by the called program as lower case written variable names, no matter which case you used in E<lt>?GETURL>.

=item B<Note>

It is highly recommended to use lower case variable names. Due to historical reasons CIPP converts parameter names to lower case without telling you about it. If this ever gets "fixed" and you have uppercase latters, your code will break. So, use lowercase.

=item B<Example>

We are in a new.spirit environment and produce a <IMG> tag, pointing to a new.spirit object (btw: the easiest way of doing this is the <?IMG> command):

  <?GETURL NAME="x.Images.Logo" MY URLVAR=$url>
  <IMG SRC="$url">

Now we link the CGI script "/secure/messager.cgi" in a CGI::CIPP or Apache::CIPP environment. We pass some parameters to this script. (Note the case sensitivity of the parameter names, we really should use lower case variables all the time!)

  <?VAR MY NAME=$Username>hans<?/VAR>
  <?VAR MY NAME=@id>(1,42,5)<?/VAR>
  <?GETURL NAME="/secure/messager.cgi" MY URLVAR=$url
           PARAMS="$Username, @id" EVENT=delete>
  <A HREF="$url">delete messagse</A>

The CGI program "/secure/messager.cgi" recieves the parameters this way (note that the $Username parameter is seen as $Username, but EVENT is seen as $event). If you find this confusing, use always lower case variable names.

  <?INTERFACE INPUT="$event, $Username, @id">
  <?IF COND="$event eq 'delete'">
    <?MY $id_text>
    <?PERL>$id_text = join (", " @id)<?PERL>
    You are about to delete
    $username's ID's?: $id_text<BR>
  <?/IF>

=back

=head1 COMMAND E<lt>?HIDDENFIELDS>

=over 8

=item B<Type>

URL and Form Handling

=item B<Syntax>

 <?HIDDENFIELDS [ PARAMS=parameter_variables ]
                [ PAR_1=value_1 ... PAR_n=value_n ] >

=item B<Description>

This command produces a number of E<lt>INPUT TYPE=HIDDEN> HTML tags, one for each parameter you specify. Use this to transport a bunch of parameters via a HTML form. This command takes care of special characters in the parameter values and quotes them if necessary.

=item B<Parameter>

=item B<     PARAMS>

This takes a comma separated list of parameters, which will be encoded and transformed to a E<lt>INPUT TYPE=HIDDEN> HTML tag. You may pass scalar variables (indicated through the $ sign) and also array variables (indicated through the @ sign).

With the PARAMS option you can only pass parameters whose values are stored in variables with the same name (where case is significant).

=item B<     PAR_1..PAR_n>

Any additional parameters to E<lt>?HIDDENFIELDS> are interpreted as named parameters.  You can pass scalar and array values this way (using $ and @). Variables passed this way are seen by the called program as lower case written variable names, no matter which case you used in E<lt>?HIDDENFIELDS>.

=item B<Example>

This is a form in a new.spirit environment, pointing to the object "x.secure.messager". The two parameters $username and $password are passed via PARAMS, the parameter "event" is set to "show".

  <?FORM ACTION="x.secure.messager">
  <?HIDDENFIELDS PARAMS="$username, $password"
                 event="show">
  <INPUT TYPE=SUBMIT VALUE="show messages">
  <?/FORM>

=back

=head1 COMMAND E<lt>?HTMLQUOTE>

=over 8

=item B<Type>

URL and Form Handling

=item B<Syntax>

 <?HTMLQUOTE VAR=variable_to_encode
             [ MY ] HTMLVAR=target_variable >

=item B<Description>

This command quotes the content of a variable, so that it can be used inside a HTML option or E<lt>TEXTAREA> block without the danger of syntax clashes. The following conversions are done in this order:

  &  =>  &amp;

  <  =>  &lt;

  "  =>  &quot;

=item B<Parameter>

=item B<     VAR>

This is the scalar variable containing the parameter you want to be quoted.

=item B<     HTMLVAR>

This non-optional parameter takes the variable where the quoted content will be stored.

=item B<     MY>

If you set the MY switch the created variable will be declared using 'my'. Its scope reaches to the end of the block which surrounds the E<lt>?HTMLQUOTE> command.

=item B<Example>

We produce a <TEXTAREA> tag with a quoted instance of the variable $text. Note: you can also use the <?TEXTAREA> command for this purpose.

  <?HTMLQUOTE VAR="$text" MY HTMLVAR="$html_text">
  <TEXTAREA NAME="text">$html_text</TEXTAREA>

=back

=head1 COMMAND E<lt>?IF>

=over 8

=item B<Type>

Control Structure

=item B<Syntax>

 <?IF COND=condition >
 ...
 [ <?ELSIF COND=condition > ]
 ...
 [ <?ELSE> ]
 ...
 <?/IF>

=item B<Description>

The E<lt>?IF> command executes the enclosed block if the condition is true. E<lt>?ELSE> and E<lt>?ELSIF> can be used inside an E<lt>?IF> block in the common manner.

=item B<Parameter>

=item B<     COND>

This takes a Perl condition. If this condition is true, the code inside the E<lt>?IF> block is executed.

=item B<Example>

Only Larry gets a greeting message here.

  <?IF COND="$name eq 'Larry'">
    Hi Larry!
  <?/IF>

=back

=head1 COMMAND E<lt>?IMG>

=over 8

=item B<Type>

HTML Tag Replacement

=item B<Syntax>

 <?IMG SRC=image_file
       [ additional_<IMG>_parameters ... ] >

=item B<Description>

A HTML E<lt>IMG> Tag will be generated, whoms SRC option points to the appropriate image URL.

=item B<Parameter>

=item B<     SRC>

This is the name of the image, expected as an URL in CGI::CIPP or Apache::CIPP environments and in dotC<-s>eparated object notation in a new.spirit environment.

=item B<     additional_IMG_parameters>

All additional parameters are taken without changes into the produced E<lt>IMG> tag.

=item B<Example>

In a new.spirit environment we produce a image link to another page, setting the border to 0.

  <?A HREF="x.main.menu">
  <?IMG SRC="x.images.logo" BORDER=0>
  <?/A>

In CGI::CIPP or Apache::CIPP environment we provide an URL instead of a dotC<-s>eparated object name.

  <?A HREF="/main/menu.cgi">
  <?IMG SRC="/images/logo.jpg" BORDER=0>
  <?/A>

=back

=head1 COMMAND E<lt>?INCINTERFACE>

=over 8

=item B<Type>

Interface

=item B<Syntax>

 <?INCINTERFACE [ INPUT=list_of_variables ]
                [ OPTIONAL=list_of_variables
                [ NOQUOTE=list_of_variables ]
                [ OUTPUT=list_of_variables ] >

=item B<Description>

Use this command to declare an interface for an Include file. You can use this inside the Include file. In order to declare the interface of a CGI file this, use the E<lt>?INTERFACE> command.

You can declare mandatory and optional parameters. Parameters are always identified by name, not by position like in many programming languages. You can pass all types of Perl variables (scalars, arrays and hashes, also references). Also you can specify output parameters, which are passed back to the caller. Even these parameters are named, which requires some getting used to for most people. However it is very useful. :)

All input parameters declared this way are visible as the appropriate variables inside the Include file. They are always declared with my to prevent name clashes with other parts of the program.

=item B<Parameter>

All parameters of E<lt>?INCINTERFACE> expect a comma separated list of variables. All Perl variable types are supported: scalars ($), arrays (@)and hashes (%).  Whitespaces are ignored. Read the note beneath the NOQUOTE section about passing non scalar values to an Include.

Note: You have to use lower case variable names, because the E<lt>?INCLUDE> command converts all variable names to lower case.

=item B<     INPUT>

This parameters takes the list of variables the caller must provide in his E<lt>?INCLUDE> command (mandatory parameters).

=item B<     OPTIONAL>

The variables listed here are optional input parameters. They are always declared with my and visible inside the Include, but are set to undef, if the caller ommits them.

=item B<     OUTPUT>

If you want your Include to pass values back to the caller, list the appropriate variables here. This variables are declared with my. Set them everywhere in your Include, they will be passed back automatically.

Note: the name of the variable receiving the output from the include must be different from the name of the output parameter. This is due to restrictions of the internal implementation.

=item B<     NOQUOTE>

By default all input parameters are defined by assigning the given value using double quotes. This means it is possible to pass either string constants or string expressions to the Include, which are interpreted at runtime, in the same manner. Often this is the behaviour you expect.

You have to list input (no output) parameters in the NOQUOTE parameter if you want them to be interpreted as a real Perl expression, and not in the string context  (e.g. $i+1 will result in a string containing the value of $i concatenated with +1 in a string context, but in an incremented $i otherwise).

Note: Also you have to list all nonC<-s>calar and reference input parameters here, because array, hash and reference variables are also computed inside a string context by default, and this is usually not what you expect.

Note: Maybe this will change in future. Listing array and hash parameters in NOQUOTE will be optional, the default behaviour for those variables will change, so that they are not computed in string context by default.

=item B<Notes>

The E<lt>?INCINTERFACE> command may occur several times inside one Include file. The position inside the source code does not matter. All declarations will be added to an interface accordingly.

If you ommit a E<lt>?INCINTERFACE> command inside your Include, its interface is empty. That means, you cannot pass any parameters to it. If you try so this will result in an error message at CIPP compile time.

=item B<Example>

This example declares an interface, expecting some scalars and an array. Note the usage of NOQUOTE for the array input parameter. The Include also returns a scalar and an array parameter.

  <?INCINTERFACE INPUT="$firstname, $lastname"
                 OPTIONAL="@id"
                 OUTPUT="$scalar, @list"
                 NOQUOTE="@id">
...

  <?PERL>
    $scalar="returning a scalar";
    @list= ("returning", "a", "list");
  <?/PERL>

The caller may use this <?INCLUDE> command. Note that all input parameter names are converted to lower case.

  <?INCLUDE NAME="/include/test.inc"
            FIRSTNAME="Larry"
            lastname="Wall"
            ID="(5,4,3)"
            MY
            $s=SCALAR
            @l=LIST>

=back

=head1 COMMAND E<lt>?INCLUDE>

=over 8

=item B<Type>

Import

=item B<Syntax>

 <?INCLUDE NAME=include_name
         [ input_parameter_1=Wert1 ... ]
         [ MY ]
         [ variable_1=output_parameter_1 ... ] >

=item B<Description>

Use Includes to divide your project into reusable pieces of code. Includes are defined in separate files. They have a well defined interface due to the E<lt>?INCINTERFACE> command. CIPP performs parameter checking for you and complain about unknown or missing parameters.

The Include file code will be inserted at the same position you write E<lt>?INCLUDE>, inside of a Perl block. Due to this variables declared inside the Include are not valid outside.

Please refer to the E<lt>?INCINTERFACE> chapter to see how parameters are processed by an Include.

=item B<Parameter>

=item B<     NAME>

This is the name of the Include file, expected as an URL in CGI::CIPP or Apache::CIPP environments and in dotC<-s>eparated object notation in a new.spirit environment.

=item B<     INPUT-PARAMETERS>

You can pass parameters to the Include using the usual PARAMETER=VALUE notation. Note that parameter names are converted to lower case. For more details about Include input parameters refer to the appropriate section of the E<lt>?INCINTERFACE> chapter.

=item B<     OUTPUT-PARAMETERS>

You can recieve parameters from the Include using the notation

{$@%}variable=output_parameter

Note that the name of the output parameters are automatically converted to lower case. Note also that the caller must not use the same name like the output parameter for the local variable which recieves the output parameter. That means for the above notation that variable must be different from output_parameter, ignoring the case.

For more details about Include output parameters refer to the appropriate section of the E<lt>?INCINTERFACE> chapter.

=item B<     MY>

If you set the MY switch all created output parameter variables will be declared using 'my'. Their scope reaches to the end of the block which surrounds the E<lt>?INCLUDE> command.

Important note

The actual CIPP implementation does really include the Include code at the position where the E<lt>?INCLUDE> command occurs. This affects variable scoping. All variables visible at the callers source code where you write the E<lt>?INCLUDE> command are also visible inside your Include. So you can use these variables, although you never declared them inside your Include. Use of this feature is discouraged, in fact you should avoid the usage of variables you did not declared in your scope.

Short notation

In a new.spirit environment the E<lt>?INCLUDE> command can be abbreviated in the following manner:

  <?include_name
      [ input_parameter_1=Wert1 ... ]
      [ MY ]
      [ variable_1=output_parameter_1 ... ] >

=item B<Example>

See example of <?INCINTERFACE>.

=back

=head1 COMMAND E<lt>?INPUT>

=over 8

=item B<Type>

HTML Tag Replacement

=item B<Syntax>

 <?INPUT [ VALUE=parameter_value ]
         [ additional_<INPUT>_parameters ... ] >

=item B<Description>

This generates a HTML E<lt>INPUT> tag where the content of the VALUE option is escaped to prevent HTML syntax clashes.

=item B<Parameter>

=item B<     VALUE>

This is the VALUE of the corresponding E<lt>INPUT> tag. Its content will be escaped.

=item B<     additional_INPUT_parameters>

All additional parameters are taken without changes into the generated E<lt>INPUT> tag.

=item B<Example>

We generate two HTML input fields, a simple text and a password field, both initialized with some values.

  <?VAR MY NAME=$username>larry<?/VAR
  <?VAR MY NAME=$password>this is my "password"<?/VAR>
  <?INPUT TYPE=TEXT SIZE=40 VALUE=$username>
  <?INPUT TYPE=PASSWORD SIZE=40 VALUE=$password>
This will produce the following HTML code:

  <INPUT TYPE=TEXT SIZE=40 VALUE="larry">
  <INPUT TYPE=TEXT SIZE=40
         VALUE="this ist my &quot;password&quot;">

=back

=head1 COMMAND E<lt>?INTERFACE>

=over 8

=item B<Type>

Interface

=item B<Syntax>

 <?INTERFACE [ INPUT=list_of_variables ]
             [ OPTIONAL=list_of_variables ] >

=item B<Description>

This command declares the interface of a CGI program. You can declare mandatory and optional parameters. Parameters are always identified by their name. You can recieve scalar and array parameters.

All input parameters declared this way are visible as the appropriate variables inside the CGI program. They are always declared with my to prevent name clashes with other parts of the program.

Using E<lt>?INTERFACE> is optional, if you are not in 'use strict' mode. If you ommit E<lt>?INTERFACE> all actual parameters are passed to your program, no parameter checking is done in this case. But it is strongly recommended to use E<lt>?INTERFACE> because CIPP checks the consistency of your CGI calls at runtime.

If you are in 'use strict' mode (which is the default), using E<lt>?INTERFACE> is mandatory, because one cannot create lexical variables at runtime. They must be declared in this manner, so CIPP can add the appropriate decalaration statements to the generated source code.

=item B<Parameter>

All parameters of E<lt>?INTERFACE> expect a comma separated list of variables. Scalars ($) and arrays (@) are supported. Whitespaces are ignored.

Note: It is recommended that you use lower case variable names for your CGI interfaces, because some CIPP commands for generating URLs (e.g. E<lt>?GETURL>) convert parameter names to lower case.

=item B<     INPUT>

This parameters takes the list of variables the caller must pass to the CGI program.

=item B<     OPTIONAL>

The variables listed here are optional input parameters. They are always declared with  my and visible inside the program, but are set to undef, if the caller ommits them.

=item B<Notes>

The E<lt>?INTERFACE> command may occur several times inside a CGI program, the position inside the source code does not matter. All declarations will be added to an interface accordingly.

=item B<Example>

We specify an interface for two scalars and an array.

  <?INTERFACE INPUT="$firstname, $lastname"
              OPTIONAL="@id">

A HTML form which adresses this CGI program may look like this (assuming we are in a CGI::CIPP or Apache::CIPP environment).

  <?VAR MY NAME="@id" NOQUOTE>(1,2,3,4)<?/VAR>

  <?FORM ACTION="/user/save.cgi">
    <?HIDDENFIELDS PARAMS="@id">
    <P>firstname:
    <?INPUT TYPE=TEXT NAME=firstname>
    <P>lastname:
    <?INPUT TYPE=TEXT NAME=lastname>
  <?/FORM>

=back

=head1 COMMAND E<lt>?LIB>

=over 8

=item B<Type>

Import

=item B<Syntax>

 <?LIB NAME=perl_module >

=item B<Description>

With this command you can access the extensive Perl module library. You can access any Perl module which is installed on your system.

In a new.spirit environment you can place user defined modules in the prod/lib directory of your project, which is included in the library search path by default.

=item B<Parameter>

=item B<     NAME>

This is the name of the module you want to use. Nested module names are delimited by ::. This is exactly what the Perl use pragma expects (you guessed right, CIPP simply translates E<lt>?LIB> to use :-).

It is not possible to use a variable or expression for NAME, you must always use a literal string here.

=item B<Example>

The standard modules File::Path and Text::Wrap are imported to your program.

  <?LIB NAME="File::Path">
  <?LIB NAME="Text::Wrap">

=back

=head1 COMMAND E<lt>?LOG>

=over 8

=item B<Type>

Exception Handling

=item B<Syntax>

 <?LOG MSG=error_message
       [ TYPE=type_of_message ]
       [ FILENAME=special_logfile ]
       [ THROW=exception ] >

=item B<Description>

The E<lt>?LOG> command adds a line to the project specific logfile, if no other filename is specified. In new.spirit environments the default filename of the logfile is prod/log/cipp.log. In CGI::CIPP and Apache::CIPP environments messages are written to /tmp/cipp.log (c:\tmp\cipp.log under Win32) by default.

Log file entries contain a timestamp, client IP adress, a message type and the message itself.

=item B<Parameter>

=item B<     MSG>

This is the message.

=item B<     TYPE>

You can use the TYPE parameter to speficy a special type for this message. This is simply a string. You can use this feature to ease logfile analysis.

=item B<     FILENAME>

If you want to add this message to a special logfile you pass the full path of this file with FILENAME.

=item B<     THROW>

With this parameter you can provide a user defined exception to be thrown on failure. The default exception thrown by this statement is log.

An exception will be thrown, if the log file is not writable or the path is not reachable.

=item B<Example>

If the variable $error is set a simple entry will be added to the default logfile.

  <?IF COND="$error != 0">
    <?LOG MSG="internal error: $error">
  <?/IF>

The error message "error in SQL statement" is added to the special logfile with the path /tmp/my.log. This entry is marked with the special type dberror. If this file is not writable an exception called fileio is thrown.

  <?LOG MSG="error in SQL statement"
        TYPE="dberror"
        FILE="/tmp/my.log"
        THROW="fileio">

=back

=head1 COMMAND E<lt>?MY>

=over 8

=item B<Type>

Variables and Scoping

=item B<Syntax>

 <?MY [ VAR=list_of_variables ]
      variable_1 ... variable_N >

=item B<Description>

This command declares private variables, using the Perl command my internally. Their scope reaches to the end of the block which surrounds the E<lt>?MY> command, for example only inside a E<lt>?IF> block.

All types of Perl variables (Scalars, Arrays and Hashes) can be declared this way.

If you want to initialize the variables with a value you must use the  E<lt>?VAR> command or Perl commands directly. E<lt>?MY> only declares variables. Their initial value is undef.

=item B<Parameter>

=item B<     VAR>

This parameter takes a comma separated list of variable names, that should be declared. With this option it is possible to declare variables which are not in lower case.

=item B<     variable_1..variable_N>

You can place additionel variables everywhere inside the E<lt>?MY> command. This variables are always declared in lower case notation.

=item B<Note:>

If you need a new variable for another CIPP command, you can most often use the MY switch of that command, which declares the variable for you. This saves you one additional CIPP command and makes your code more readable.

=item B<Example>

See <?BLOCK>.

=back

=head1 COMMAND E<lt>?PERL>

=over 8

=item B<Type>

Control Structure

=item B<Syntax>

 <?PERL [ COND=condition ] >
 ...
 <?/PERL>

=item B<Description>

With this command you open a block with pure Perl commands. You may place any valid Perl code inside this block.

You may use the Perl print statement to produce HTML code (or whatever output you want) for the client.

At the moment, there are only two CIPP commands which are actually supported inside a E<lt>?PERL> block: E<lt>?INCLUDE> and E<lt>?SQL>. Support of more commands will be added in the future.

=item B<Parameter>

=item B<     COND>

If you set the COND parameter, the Perl block is only executed, if the given condition is true.

=item B<Example>

All occurences of the string 'nt' in the scalar variable $str will be replaced by 'no thanks'. The result will be printed to the client.

  <?PERL>
    $text =~ s/nt/no thanks/g;
    print $text;
  <?/PERL>

If this list contains some elements a string based on the list is generated.

  <?PERL COND="scalar(@list) != 0">
    my ($string, $element);
    foreach $element ( @list ) {
      $string .= $element;
    }
    print $string;
  <?/PERL>
  # OK, its easier to use 'join', but it's
  # only an example... :-)

=back

=head1 COMMAND E<lt>?ROLLBACK>

=over 8

=item B<Type>

SQL

=item B<Syntax>

 <?ROLLBACK [ DB=database_name ]
            [ THROW=exception ] >

=item B<Description>

The E<lt>?ROLLBACK> command concludes the actual transaction and cancels all changes to the database.

Using E<lt>?ROLLBACK> in E<lt>?AUTOCOMMIT ON> mode is not possible.

If you are not in E<lt>?AUTOCOMMIT ON> mode a transaction begins with the first SQL statement and ends either with a E<lt>?COMMIT> or E<lt>?ROLLBACK> command.

=item B<Parameter>

=item B<     DB>

This is the CIPP internal name of the database for this command. In CGI::CIPP or Apache::CIPP environment this name has to be defined in the appropriate global configuration. In a new.spirit environment this is the name of the database configuration object in dotC<-s>eparated notation.

If DB is ommited the project default database is used.

=item B<     THROW>

With this parameter you can provide a user defined exception which should be thrown on failure. The default exception thrown by this statement is rollback.

If the underlying database is not capable of transactions (e.g. MySQL) execution of this command will throw an exception.

=item B<Example>

We insert a row into a database table and rollback the change immediately. We throw a user defined exeption, if the rollback fails, maybe the database is not capable of transactions.

  <?SQL SQL="insert into foo (num, str)
             values (42, 'bar');">
  <?/SQL>
  <?ROLLBACK THROW="ROLLBACK_Exception">

=back

=head1 COMMAND E<lt>?SAVEFILE>

=over 8

=item B<Type>

Interface

=item B<Syntax>

 <?SAVEFILE FILENAME=server_side_filename
            VAR=upload_formular_variable
            [ SYMBOLIC ]
            [ THROW=exception ] >

=item B<Description>

This command saves a file which was uploaded by a client in the webservers filesystem.

=item B<Parameter>

=item B<     FILENAME>

This is the fully qualified filename where the file will be stored.

=item B<     VAR>

This is the identifier you used in the HTML form for the filename on client side, the value of the E<lt>INPUT NAME> parameter) .

=item B<     SYMBOLIC>

If this switch is set, VAR is the name of the variable which contains the E<lt>INPUT TYPE=FILE> identifier. Use this if you want to determine the name of the field at runtime.

=item B<     THROW>

With this parameter you can provide a user defined exception which should be thrown on failure. The default exception thrown by this statement is savefile.

=item B<Note>

The client side file upload will only function proper if you set the encoding type of the HTML form to ENCTYPE="multipart/form-data". Otherwise you will get a exception, that the file could not be fetched.

=item B<Example>

First we provide a HTML form with the file upload field.

  <?FORM METHOD="POST" ACTION="/image/save.cgi"
         ENCTYPE="multipart/form-data">
Fileupload:

  <INPUT TYPE=FILE NAME="upfilename" SIZE=45><BR>
  <INPUT TYPE="reset">
  <INPUT TYPE="submit" NAME="submit" VALUE="Upload">
  </FORM>

The /image/save.cgi program has the following code to store the file in the filesystem.

  <?SAVEFILE FILENAME="/tmp/upload.tmp"
             VAR="upfilename"
             THROW=my_upload>

The same procedure using the RUNTIME parameter.

  <?VAR MY=$field_name>upfilename<?/VAR>
  <?SAVEFILE FILENAME="/tmp/upload.tmp"
             SYMBOLIC
             VAR="$field_name"
             THROW=upload>

=back

=head1 COMMAND E<lt>?SQL>

=over 8

=item B<Type>

SQL

=item B<Syntax>

 <?SQL SQL=sql_statement
       [ VAR=list_of_variables_for_the_result ]
       [ PARAMS=input_parameter ]
       [ WINSTART=start_row ]
       [ WINSIZE=number_of_rows_to_fetch ]
       [ RESULT=sql_return_code ]
       [ DB=database_name ]
       [ THROW=exception ] >
       [ MY ]
 ...
 <?/SQL>

=item B<Description>

Use the E<lt>?SQL> command to execute arbitrary SQL statements in a specific database. You can fetch results from a SELECT query, or simply execute INSERT, UPDATE or other SQL statements.

When you execute a SELECT query (resp. set the VAR parameter, see below) the code inside the E<lt>?SQL> block will be repeated for every row returned from the database.

=item B<Parameter>

=item B<     SQL>

This takes the SQL statement to be executed. A trailing semicolon will be stripped off.

The statement may contain ? placeholders. They will be replaced by the expressions listed in the PARAMS parameter. See the PARAMS section for details about placeholders.

This is an example of a simple insert without placeholders.

  <?SQL SQL="insert into foo values (42, 'bar')">
  <?/SQL>

=item B<     VAR>

If you set the VAR parameter, CIPP asumes that you execute a SQL statement which returns a result set (normally a SELECT statement).

The VAR parameter takes a list of scalar variables. Each variable corresponds to the according column of the result set,  so the position of the variables inside the list is relevant.

You can use this variable inside the E<lt>?SQL> block to access the actual processed row of the result set. Below the E<lt>?SQL> block the variable contains the values of the last row fetched, even when they are implicitely declared via a MY switch.

This is an example of creating a simple HTML table out of an SQL result set.

  <TABLE>
    <?SQL SQL="select num, str from foo"
          MY VAR="$n, $s">
      <TR>
        <TD>$n</TD>
        <TD>$s</TD>
      </TR>
    <?/SQL>
  </TABLE>

=item B<     PARAMS>

All placeholders inside your SQL statement will be replaced with the values given in PARAMS. It expects a comma separated list (white spaces are ignored) of Perl expressions, normally variables (scalar or array), literals or constants. The Perl value undef will be translated to the SQL value NULL.  The content of the first expression substitutes the first placeholder in the SQL string, etc.

Values of parameters are quoted, if necessary, before substitution.  This is the main advantage of PARAMS in this context. (You could place the perl variables into the SQL statement as such, but you would have to use E<lt>?DBQUOTE> on them first. Or else.).

Beware that you cannot use placeholders to contain (parts of) SQL code. The SQL must contain the syntactically complete statement - placeholders can only contain values. (The main reason for this is that the SQL statement is parsed by most databases before the placeholders are substituted. See the DBI manpage for details about placeholders.)

Here are some examples which demonstate the usage of placeholders.

  <?VAR MY NAME=$n>42<?/VAR>
  <?VAR MY NAME=$s>Hello 'World'<?/VAR>
  <?SQL SQL="insert into foo values (?, ?, ?)"
        PARAMS="$n, $s, time()">
  <?/SQL>

  <?VAR MY NAME=$where_num>42<?/VAR>
  <?SQL SQL="select num,str from foo
             where num = ?"
        PARAMS="$where_num">
        MY VAR="$column_n, $column_s">
    n=$column_n s='$column_s'<BR>
  <?/SQL>

  <?SQL SQL="update foo
             set str=?
             where n=?"
        PARAMS="$s, $where_num">
  <?/SQL>

=item B<     WINSTART>

If you want to process only a part of the result set you can specfiy the first row you want to see with the WINSTART parameter. All rows before the given WINSTART row will be fetched but ignored. Execution of the E<lt>?SQL> block begins with the WINSTART row.

The row count begins with 1.

Here is an example. The first 5 rows will be skipped.

  <?SQL SQL="select num, str from foo"
        MY VAR="$n, $s"
        WINSTART=6
    n=$n s='$s'<BR>
  <?/SQL>

=item B<     WINSIZE>

Set this parameter to specify the number of rows you want to process. You can combine this parameter with WINSTART to process a "window" of the result set.

This is an example of doing this (skipping 5 rows, processing 5 rows).

  <?SQL SQL="select num, str from foo"
        MY VAR="$n, $s"
        WINSTART=6 WINSIZE=5
    n=$n s='$s'<BR>
  <?/SQL>

=item B<     RESULT>

Some SQL statements return a scalar result value, e.g. the number of rows processed (e.b. UPDATE and DELETE). The variable placed here will take the SQL result code, if there is one.

Example:

  <?SQL SQL="delete from foo where num=42"
        MY RESULT=$deleted>
  <?/SQL>
Successfully deleted $deleted rows!

=item B<     DB>

This is the CIPP internal name of the database for this command. In CGI::CIPP or Apache::CIPP environment this name has to be defined in the appropriate global configuration. In a new.spirit environment this is the name of the database configuration object in dotC<-s>eparated notation.

If DB is ommited the project default database is used.

=item B<     THROW>

With this parameter you can provide a user defined exception which should be thrown on failure. The default exception thrown by this statement is sql.

=item B<     MY>

If you set the MY switch all created variables will be declared using 'my'. Their scope reaches to the end of the block which surrounds the E<lt>?SQL> command.

=item B<Example>

Please refer to the examples in the parameter sections above.

=back

=head1 COMMAND E<lt>?SUB>

=over 8

=item B<Type>

Control Structure

=item B<Syntax>

 <?SUB NAME=subroutine_name >
 ...
 <?/SUB>

=item B<Description>

This defines the E<lt>?SUB> block as a Perl subroutine. You may use any CIPP commands inside the block.

Generally Includes are the best way to create reusable modules with CIPP. But sometimes you need real Perl subroutines, e.g. if you want to do some OO programming.

=item B<Parameter>

=item B<     NAME>

This is the name of the subroutine. Please refer to the perlsub manpage for details about Perl subroutines.

It is not possible to declare protoyped subroutines with E<lt>?SUB>.

=item B<Example>

This is a subroutine to create a text input field in a specific layout.

  <?SUB NAME=print_input_field>
    # Catch the input parameters
    <?MY $label $name $value>
    <?PERL>
      ($label, $name, $value) = @_;
    <?/PERL>

    # print the text field
    <P>
    <B>$label:</B><BR>
    <?INPUT TYPE=TEXT SIZE=40 NAME=$name VALUE=$value>
  <?/SUB>
You may call this subroutine from every Perl context this way.

  <?PERL>
    print_input_field ('Firstname', 'firstname',
                       'Larry');
    print_input_field ('Lastname', 'surname',
                       'Wall');
  <?/PERL>

=back

=head1 COMMAND E<lt>?TEXTAREA>

=over 8

=item B<Type>

HTML Tag Replacement

=item B<Syntax>

 <?TEXTAREA [ additional_<TEXTAREA>_parameters ... ]>
 ...
 <?/TEXTAREA>

=item B<Description>

This generates a HTML E<lt>TEXTAREA> tag, with a HTML quoted content to prevent from HTML syntax clashes.

=item B<Parameter>

=item B<     additional_TEXTAREA_parameters>

There are no special parameters. All parameters you pass to E<lt>?TEXTAREA> are taken in without changes.

=item B<Example>

This creates a <TEXTAREA> initialized with the content of the variable $fulltext.

  <?VAR MY NAME=$fulltext><B>HTML Text</B><?/VAR>
  <?TEXTAREA NAME=fulltext ROWS=10
COLS=80>$fulltext<?/TEXTAREA>

This leads to the following HTML code.

  <TEXTAREA NAME=fulltext ROWS=10
COLS=80>&lt;B>HTML Text&lt;B></TEXTAREA>

=back

=head1 COMMAND E<lt>?THROW>

=over 8

=item B<Type>

Exception Handling

=item B<Syntax>

 <?THROW THROW=exception [ MSG=message ] >

=item B<Description>

This command throws an user specified exception.

=item B<Parameter>

=item B<     THROW>

This is the exception identifier, a simple string. It is the criteria for the E<lt>?CATCH> command.

=item B<     MSG>

Optionally, you can pass a additional message for your exception, e.g. a  error message you have got from a system call.

=item B<Example>

We try to open a file and throw a exception if this fails.

  <?MY $error>
  <?PERL>
    open (INPUT, '/bar/foo') or $error=$!;
  <?/PERL>

  <?IF COND="$error">
    <?THROW THROW="open_file"
            MSG="file /bar/foo, $error">
  <?/IF>

=item B<Note>

If you want to throw a exception inside a Perl block you can do this with the Perl die function. The die argument must follow this convention:

  identifier TAB message

This is the above example using this technique.

E<lt>?PERL>

  open (INPUT, '/bar/foo')

    or die "open_file\tfile /bar/foo, $!";

E<lt>?/PERL>

=back

=head1 COMMAND E<lt>?TRY>

=over 8

=item B<Type>

Exception Handling

=item B<Syntax>

 <?TRY >
 ...
 <?/TRY >

=item B<Description>

Normally your program exits with a general exception message if an error/exception occurs or is thrown explicitely. The general exception handler which is responsible for this behaviour is part of any program code which CIPP generates.

You can provide your own exception handling using the E<lt>?TRY> and E<lt>?CATCH> commands.

All exceptions thrown inside a E<lt>?TRY> block are caught. You can use a subsequent E<lt>?CATCH> block to process the exceptions to set up your own exception handling.

If you ommit the E<lt>?CATCH> block, nothing will happen. You never see something of the exception, it will be fully ignored and the program works on.

=item B<Example>

We try to insert a row into a database table and write a log file entry with the error message, if the INSERT fails.

  <?TRY>
    <?SQL SQL="insert into foo values (42, 'bar')">
    <?/SQL>
  <?/TRY>

  <?CATCH THROW="insert" MY MSGVAR="$msg">
    <?LOG MSG="unable to insert row, $msg"
          TYPE="database">
  <?/CATCH>

=back

=head1 COMMAND E<lt>?URLENCODE>

=over 8

=item B<Type>

URL and Form Handling

=item B<Syntax>

 <?URLENCODE VAR=unencoded_variable
             [ MY ] ENCVAR=encoded_variable >

=item B<Description>

Use this command to URL encode the content of a scalar variable. Parameters passed via URL always have to be encoded this way, otherwise you risk syntax clashes.

=item B<Parameter>

=item B<     VAR>

This is the variable you want to be encoded.

=item B<     ENCVAR>

The encoded result will be stored in this variable.

=item B<     MY>

If you set the MY switch the created variable will be declared using 'my'. Its scope reaches to the end of the block which surrounds the E<lt>?URLENCODE> command.

=item B<Example>

In this example we link an external CGI script and pass the content of the variable $query after using <?URLENCODE> on it.

  <?URLENCODE VAR=$query MY ENCVAR=$enc_query>
  <A HREF="www.search.org?query=$enc_query">
find something

  </A>

Hint: in CGI::CIPP and Apache::CIPP environments you also can use the <?A> command for doing this.

=back

=head1 COMMAND E<lt>?VAR>

=over 8

=item B<Type>

Variables and Scoping

=item B<Syntax>

 <?VAR NAME=variable
       [ MY ]
       [ DEFAULT=value ]
       [ NOQUOTE ]>
 ...
 <?/VAR>

=item B<Description>

This command defines and optionally declares a Perl variable of any type (scalar, array and hash). The value of the variable is derived from the content of the E<lt>?VAR> block. You can assign constants, string expressions and any Perl expressions this way.

It is not possible to nest the E<lt>?VAR> command or to use any CIPP command inside the E<lt>?VAR> block. The content of the E<lt>?VAR> block will be evaluated and assigned to the variable.

=item B<Parameter>

=item B<     NAME>

This is the name of the variable. You must specify the full Perl variable here, including the $, @ or % sign to indicate the type of the variable.

These are some examples for creating variables using E<lt>?VAR>.

  <?VAR NAME=$skalar>a string<?/VAR>
  <?VAR NAME=@liste>(1,2,3,4)<?/VAR>
  <?VAR NAME=%hash>( 1 => 'a', 2 => 'b' )<?/VAR>

=item B<     DEFAULT>

If you set the DEFAULT parameter, this value will be assigned to the variable, if the variable is actually undef. In this case the content of the E<lt>?VAR> block will be ignored.

Setting the DEFAULT parameter is only supported for scalar variables.

You can use this feature to provide default values for input parameters this way.

  <?VAR NAME=$event DEFAULT="show">$event<?/VAR>

Hint: you may think there must be a easier way of doing this. You are right. :-) We recommend you using this alternative code, the usage of DEFAULT is deprecated.

  <?PERL>
    $event ||= 'show';
  <?/PERL>

=item B<     NOQUOTE>

By default the variable is defined by assigning the given value using double quotes. This means it is possible to assign either string constants or string expressions to the variable without using extra quotes.

If you do not want the content of E<lt>?VAR> block to be evaluated in string context set the NOQUOTE switch. E.g., so it is possible to assign an integer expression to the variable.

This is an example of using NOQUOTE for an non string expression.

  <?VAR MY NAME=$element_cnt NOQUOTE>
    scalar(@liste)
  <?/VAR>

=item B<     MY>

If you set the MY switch the created variable will be declared using 'my'. Its scope reaches to the end of the block which surrounds the E<lt>?VAR> command.

=item B<Example>

Please refer to the examples in the parameter sections above.

=back

=head1 COMMAND E<lt>?WHILE>

=over 8

=item B<Type>

Control Structure

=item B<Syntax>

 <?WHILE COND=condition >
 ...
 <?/WHILE>

=item B<Description>

This realizes a loop, where the condition is checked first before entering the loop code.

=item B<Parameter>

=item B<     COND>

As long as this Perl condition is true, the E<lt>?WHILE> block will be repeated.

=item B<Example>

This creates a HTML table out of an array using <?WHILE> to iterate over the two arrays @firstname and @lastname, assuming that they are of identical size.

  <TABLE>
  <?VAR MY NAME=$i>0<?/VAR>
  <?WHILE COND="$i++ < scalar(@lastname)">
    <TR>
      <TD>$lastname[$i]</TD>
      <TD>$firstname[$i]</TD>
    </TR>
  <?/WHILE>
  </TABLE>

=back

=head1 AUTHOR

Joern Reder <joern@dimedis.de>

=head1 COPYRIGHT

Copyright (C) 1999 by dimedis GmbH, All Rights Reserved.
This documentation is free; you can redistribute it and/or
modify it under the same terms as Perl itself.
