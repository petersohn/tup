#! /bin/sh -e

# For this bug, we have to create some command objects to be deleted. We need
# to successfully compile one file (bar.c). Then we change the commands, so the
# old ones are scheduled for deletion. The next update compiles bar.c again,
# but fails because foo.c is incorrect. This causes us to still have the old
# commands marked as deleted, but they haven't happened yet because we stopped
# on foo.c. Then foo.c is modified to be correct, and another update runs. Now
# the new (correct) command for bar.c is not in the partial DAG, but the old
# command to be deleted is. This causes bar.o to be incorrectly deleted on the
# third update
. ../tup.sh
cat > Tupfile << HERE
: foreach *.c |> gcc -c %f -o %o |> %F.o
: *.o |> gcc %f -o %o |> prog
HERE

mkdir include
touch include/foo.h
(echo "#include \"foo.h\""; echo "void foo(void) {bork}") > foo.c
echo "int main(void) {}" > bar.c
tup touch include/foo.h foo.c bar.c Tupfile
update_fail
check_not_exist foo.o prog
check_exist bar.o

tup_object_exist . 'gcc -c foo.c -o foo.o'
tup_object_exist . 'gcc -c bar.c -o bar.o'

cat > Tupfile << HERE
: foreach *.c |> gcc -c %f -o %o -Iinclude |> %F.o
: *.o |> gcc %f -o %o |> prog
HERE
tup touch Tupfile
update_fail
check_not_exist foo.o prog

(echo "#include \"foo.h\""; echo "void foo(void) {}") > foo.c
tup touch foo.c
update
sym_check foo.o foo
sym_check bar.o main
sym_check prog main

tup_object_exist . 'gcc -c foo.c -o foo.o -Iinclude'
tup_object_exist . 'gcc -c bar.c -o bar.o -Iinclude'
tup_object_no_exist . 'gcc -c foo.c -o foo.o'
tup_object_no_exist . 'gcc -c bar.c -o bar.o'
