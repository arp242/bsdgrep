BSD grep from FreeBSD for Linux.

Imported from [freebsd-src], commit caf5283 (Sep 2023); this became the default
`grep` in [FreeBSD 13]:

> Switch to the BSDL grep implementation now that it's been a little more
> thoroughly tested and theoretically supports all of the extensions that
> gnugrep in base had with our libregex(3).
>
> Folks shouldn't really notice much from this update; bsdgrep is slower than
> gnugrep, but this is currently the price to pay for fewer bugs. Those
> dissatisfied with the speed of grep and in need of a faster implementation
> should check out what textproc/ripgrep and textproc/the_silver_searcher can do
> for them.

Run `update.sh` to update the sources, and use the standard `make` and `make
install` to install it.

TODO: port the tests as well.

[freebsd-src]: https://github.com/freebsd/freebsd-src/tree/main/usr.bin/grep
[FreeBSD 13]: https://cgit.freebsd.org/src/commit/?id=b82a9ec5f53e
