# Devel::LeakGuard::Object

This module provides tracking of objects, for the purpose of detecting memory
leaks due to circular references or innappropriate caching schemes.

It is derived from, and backwards compatible with Adam Kennedy's
[Devel::Leak::Object](https://metacpan.org/pod/Devel::Leak::Object). Any
errors are mine.

## Version

0.07

## Installation

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

## Dependencies

None.

## Copyright and Licence

Copyright (C) 2009-2015, Andy Armstrong

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
