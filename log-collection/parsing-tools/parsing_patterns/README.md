### Asterisk Logging Script

#### Limitations
Asterisk used strftime specifiers in `dateformat` field to format the time(https://wiki.asterisk.org/wiki/display/AST/Logging+Configuration).

This script will handle the `dateformat` field. But it
1. Doesn't handle Modifier(`%O` and `%E`) in strftime
   ```
       Some conversion specifications can be modified by preceding the
       conversion specifier character by the E or O modifier to indicate
       that an alternative format should be used.  If the alternative format
       or specification does not exist for the current locale, the behavior
       will be as if the unmodified conversion specification were used. (SU)
       The Single UNIX Specification mentions %Ec, %EC, %Ex, %EX, %Ey, %EY,
       %Od, %Oe, %OH, %OI, %Om, %OM, %OS, %Ou, %OU, %OV, %Ow, %OW, %Oy,
       where the effect of the O modifier is to use alternative numeric
       symbols (say, roman numerals), and that of the E modifier is to use a
       locale-dependent alternative representation.
   ```


2. Doesn't support the glibc extensions for conversion specifications. All the additional specifications will be regarded as literal values.
   (e.g. an optional flag and field width may be specified.)
   ```
     Glibc notes
       Glibc provides some extensions for conversion specifications.  (These
       extensions are not specified in POSIX.1-2001, but a few other systems
       provide similar features.)  Between the '%' character and the
       conversion specifier character, an optional flag and field width may
       be specified.  (These precede the E or O modifiers, if present.)

       The following flag characters are permitted:

       _      (underscore) Pad a numeric result string with spaces.

       -      (dash) Do not pad a numeric result string.

       0      Pad a numeric result string with zeros even if the conversion
              specifier character uses space-padding by default.

       ^      Convert alphabetic characters in result string to uppercase.

       #      Swap the case of the result string.  (This flag works only
              with certain conversion specifier characters, and of these, it
              is only really useful with %Z.)

       An optional decimal width specifier may follow the (possibly absent)
       flag.  If the natural size of the field is smaller than this width,
       then the result string is padded (on the left) to the specified
       width.
   ```
   
Ref: http://man7.org/linux/man-pages/man3/strftime.3.html