RcrdCarver

This is a simple tool to dump individual RCRD records. It scans the input for signatures in addition to record validations. Input must be a file.

Syntax is:
RcrdCarver.exe /InputFile: /OutputPath:

Examples
RcrdCarver.exe /InputFile:c:\unallocated.chunk /OutputPath:e:\temp

If no input file is given as parameter, a fileopen dialog is launched. Output will default to program directory if omitted. Output is split in 3, in addition to a log file. Example output may look like:
Carver_Rcrd_2015-02-14_21-46-54.log
Carver_Rcrd_2015-02-14_21-46-54.wfixups.RCRD
Carver_Rcrd_2015-02-14_21-46-54.wofixups.RCRD
Carver_Rcrd_2015-02-14_21-46-54.false.positives.RCRD

This tool is handy when you have no means of accessing a healthy RCRD. For instance a memory dump or damaged volume. The tool will by default first attempt to apply fixups, and if it fails it will retry by skipping fixups. Applying fixups here means verifying the update sequence array and applying it.

Unallocated data chunks may contain RCRD records that can be easily extracted. Such records may be traces of fragments from deleted shadow copies. Such hits will be present in wfixups.RCRD. I am not aware of any system logic that would explain hits in wofixups.RCRD (so unlikely).

It is advised to check the log file generated. There will be verbose information written. Especially the false positives and their offsets can be found here, in addition to the separate output file containg all false positives.

The test of the record structure is rather comprehensive, and the output quality is excellently divided in 3.
