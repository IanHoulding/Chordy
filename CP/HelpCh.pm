package CP::HelpCh;

use CP::Global qw/:FUNC :XPM/;
use CP::Help;

sub help {
  my($win) = shift;

  if ($win eq '') {
    makeImage("checkbox", \%XPM);
    $win = CP::Help->new("Chordy Help");
    $win->add(
[
 "<O TO:H: Chordy > ",
 "Takes a standard(ish) ChordPro text file and converts it to a PDF file with the chords arranged above the lines of lyrics. Chordy can also transpose the music key, either permanently or just for the current PDF creation.",
 "Chordy works with independent sets of files called <R Collections>. Each Collection has its own set of ChordPro and PDF files and its own set of configuration options.",
 "In the applications main display you have 4 tabs:",
"<R Chordy PDF Generator> is where you get to convert your ChordPro files into a PDF file and/or Transposed etc.",
"<R Set Lists> allows you to create/modify/delete Set Lists and is also where you select one or more ChordPro files you want to edit and/or create PDFs.",
"<R Configuration Options> has the various default items and settings used in each Collection.",
"<R Miscellaneous> lets you perform various house-keeping functions.\n",
 "<O To:H: Table Of Contents >",
 "<O Ch:S:\nChordy PDF Generator>",
 "<O CP:s:ChordPro File(s)>",
 "<O SS:s:Single Selected File>",
 "<O PD:s:PDFs>",
 "<O Op:s:PDF Options>",
 "<O DI:s:Chord Diagrams>",
 "<O SL:S:\nSet Lists>",
 "<O FB:S:\nConfiguration Options>",
 "<O CL:s:Collections>",
 "<O PS:s:PDF Page Size>",
 "<O FO:s:Fonts - Colour and Size>",
 "<O BC:s:Background Colours>",
 "<O Sd:s:Save as Default>",
 "<O Ld:s:Load Defaults>",
 "<O Rd:s:Reset all Defaults>",
 "<O MU:S:\nMiscellaneous>",
 "<O Mf:s:File>",
 "<O Mo:s:Options>",
 "<O Ma:s:Appearance>",
 "<O Co:s:Commands>",
 "<O CE:S:\nColour Editor>",
 "<O CD:S:\nChordPro Files & Directives>",
 "\n",

######
 "<T Ch><H Chordy PDF Generator\n>",
 "<V5>",

 "<T CP><S ChordPro File(s)>\n",
 "<M>These are files ending with a .pro extension. The <R Browse> button allows you to select one or more files contained in the ChordPro folder (see the section on Folders and Commands).\nThe <R From Set List> button lets you pull in a list of files from a pre defined Set List.\n",

 "<P  New > ",
 "<M>Enables you to create a new ChordPro file - enters the Editor with the <R Title> directive initalised.\n",

 "<P  Import ChordPro > ",
 "<M>Lets you copy ChordPro files from somewhere into your Collection <B Pro> Folder.\n",

 "<P  Sync ChordPro > ",
 "<M>Compares the contents of a source and destination folder and syncronises them such that the destination matches the source.\n",

 "<B The following 4 sets of buttons work on whatever ChordPro files are currently listed:> \n",
 "<P  Export ChordPro > ",
 "<M>Lets you copy <R One> or <R All> ChordPro files from your Collection <B Pro> Folder to anywhere you choose.\n",

 "<P  Export PDF > ",
 "<M>As above - lets you copy <R One> or <R All> PDF files from your Collection <B PDF> Folder to anywhere you choose. This assumes that the PDF files have alreay been created from the ChordPro files. If one or more PDFs have not been created you will get a list of those that have and those that have not been exported.\n",

 "<P  Mail ChordPro > ",
 "<M>Mails <R One> or <R All> ChordPro files as attachments.\n",

 "<P  Mail PDF > ",
 "<M>Mails <R One> or <R All> PDF files as attachments with the same provisos as for Exporting.\n",

 "<T SS><S Single Selected File>\n",
 "<M>This section allows you to select ONE of the ChordPro Files (above) and perform various actions on it:\n",

 "<P  Transpose > ",
 "<M>Unlike when you create a PDF, this will permanently transpose all chords to the key defined in the PDF Options section (see below) and write the new version back out to disk.\n",

 "<P  Edit > ",
 "<M>Opens the selected file in the <B Cpgedi> Editor.\n",

 "<P  Rename > <P  Clone > and <P  Delete > ",
 "<M>Does what it says on the button :)\n",

###
 "<T PD><S PDFs>\n",
 "<M>You can elect to View, Create and/or Print all listed ChordPro files or just a single selected file.\nThe viewer is <B SumatraPDF> on Windows systems (installed with Chordy), <B Preview> on Mac and <B acroread> on Linux.",
 "The <R All Songs> button will view/create/print a PDF file for each ChordPro file in the list unless the <R Single PDF> checkbox is active in which case a single PDF file will be created containing all the songs in the order shown in the ChordPro file list.\nThe <R Single Song> button does the same as above but on the one selected ChordPro file.\n",

###
 "<T Op><S PDF Options>\n",

 "<X checkbox><s  Center Lyrics> ",
 "<M>By default, the Lyrics, Highlights, Comments etc. are printed left justified (ie against the left side of the page). Turning this option on will center all text on each page.\n",

 "<X checkbox><s  Lyrics Only> ",
 "<M>Basically does not display <I any> of the chords but everything else is displayed as it normally would be ... really only usefull to give to the vocalist :-)\n",

 "<X checkbox><s  Group Lines> ",
 "<M>Chordy will always ensure a line of Lyrics and Chords are on the same page. This option allows you to apply the same to any number of lines that are separated by a blank line, or a <R Verse>, <R Chorus> or <R Bridge> directive. This can be a combination of Lyrics, Highlighted or any Comment variation. As long as there is no blank line they will all be moved onto a new page if they would not fit on the current page. The only time this is aborted is if the collection of lines is larger than the page size - this will turn the <R Group> option off for the rest of file processing.\n",

 "<X checkbox><s  No Long Line warnings> ",
 "<M>If it has to, Chordy will adjust the Lyric font size until it fits onto a line in which case it will display a warning to that effect. This option stops those warnings appearing - they can become anoying if you're processing a large number of files. View the error log - they're copied into that.\n",

 "<X checkbox><s  Ignore Capo Directives> ",
 "<M>This option stops Chordy from Transposing chords in a file if the <B {capo:n}> option is present in the file. However, it does <I NOT> alter the action of the <R Tanspose To> option.\n",

 "<X checkbox><s  Highlight/Comment full line> ",
 "<M>Highlight and Comment text normally have a background colour <I just> around the text. This option extends the background to cover the whole line.\n",

 "<P  Line Spacing > ",
 "<M>Determines the spacing between lines. This does not affect the positioning of chords above the lyrics. I usually use a value of 1 or 2  for lyrics + chords and 4 or 5 for just lyrics.\n",

 "<P  Capo On > ",
 "<M>You can define the Capo position here. This setting will overide a <B {capo:n}> directive found in the ChordPro file. See the <B Directives> section <B Capo> for a description of how this affects the PDF output.\n",

 "<P  Transpose To > ",
 "<M>Allows you to select a key to transpose to. The app will scan the file for a {key:xx} directive (see below) to determine the original key. Failing that, it will take the first chord it finds as being the key. Be aware that if you view/create/print more than one ChordPro file, <B ALL> of them will be transposed to the same key!\n",

 "<s Force Flat/Sharp> ",
 "<M>These 2 options force all 'black' notes to be either sharps or flats. So, for example, if you want to transpose a piece to Eb, a chord that would have been Eb will be shown as D# if Force Sharp is in effect.\n",

###
 "<T DI><S Chord Diagrams>\n",

 "<M>This option set allows you to have an index of all the chords in the current song displayed at the top of the first page or the top of every page. Although the <R Instrument> button lets you select the type to display the chords for, only 6 string guitar chords are currently implemented. If you want to add chords to any of the available intruments, use the Chord Editor via the <R Edit> button.\n",

################

 "<T SL><H Set Lists\n>",
 "<V5>",

 "This tab is split into an upper and lower section.",
 "<S Upper Section>\n",
 "The upper section shows (on the left) the currently available Set Lists and to it's right a box which shows which Set List is currently selected along with date/time information and to the right of that, a number of buttons to manipulate the current Set List:\n",
 "<P  New > ",
 "<M>Creates a new Set List.",
 "<V5>",
 "<P  Rename > ",
 "<M>Renames the current Set List.",
 "<V5>",
 "<P  Clone > ",
 "<M>Produces a copy of the current Set List and gives it the new name.\n",

 "<P  Print > ",
 "<M>Puts a list of song titles onto one PDF page with a title that is the Current Set Name.",
 "<V5>",
 "<P  Export > ",
 "<M>Lets you copy the current Set List to another Collection.",
 "<V5>",
 "<P  Save > ",
 "<M>Saves any changes to the currently selected Set List.",
 "<V5>",
 "<P  Delete > ",
 "<M>Deletes the currently selected Set List after prompting.\n",
 "The date/time information for the current Set List may be entered/edited using the <R Edit> button. The various fields are completed using pop-ups - the only buttons which are unique are the ones which increment/decrement the minutes - holding the left mouse button down while over the button will cause the minutes to change rapidly.\n",
 "<S Lower Section>",
 "<V5>",
 "This is a copy of the Browser pop-up and has a Search area and 2 list boxes:",
 "The Search area lets you type in a case insensitive string and will search the <R Available Files>. The search takes place as you type and throws up a message if no match is found. The <R Find Next> button does just that and will wrap back to the begining of the list if it fails to match when the end of the list is reached.\n",
 "<E><R Available Files> ",
 "<M>A list of all ChordPro files in the current collection. Double clicking a file will automatically transfer it to the Set List Files. The alphabet buttons below the <R Available Files> list enable you to quickly jump to entries starting with the appropriate letter.",
 "<E><R Set List Files> ",
 "<M>All the files that either do, or will, make up the current Set List. Below this list are 2 buttons:",
 "<E><R Clear> ",
 "<M>Moves all the Set List Files back into the <R Available FIles> list.",
 "<E><R Select for Editing> ",
 "<M>Will place the currently selected Set List files into the <R ChordPro Files> list (on the 1st tab) and switch to that tab.\n",
 "The various arrow buttons move files between the 2 lists and allow you to change the order of the files in the Set List.\n",

################

 "<T FB><H Configuration Options\n>",
 "<V5>",

 "<T CL><S Collections>\n",
 "A <B Collection> is a grouping of ChordPro, PDF and Tab files along with various configuration files.\nThe default Collection from the install is called (wait for it ....) <B Chordy> and lives in the <R C:/Users/[USERNAME]> folder on Windows or in <R \$ENV{HOME}> on Linux/Mac.\nNote the use of Unix path separators / instead of the Windows \\ - this is historical because the Perl programming language (which Chordy is written in) was developed for the Unix environment.\nYou cannot delete a Collection if it is the only one but if you create a second Collection you can delete the original Chordy Collection. This isn't 100% accurate as the global configuration files are always left in the <R C:/Users/[USERNAME]/Chordy> or <R \$ENV{HOME}/Chordy> folder but the Pro, PDF and Tab folders are emptied.\nThe Collection section shows you the current Collection name and the path to it. Clicking on the Edit button allows you to <B Delete>, <B Rename> or create a <B New> Collection.\n(The only Collection you aren't allowed to rename is the Chordy one)\n",

 "<s Common PDF Path> ",
 "<M>This allows any combination of Collections to share a PDF Folder. For example I have one Collection for a 4 string Bass and another for a 5 string but I want to have a common PDF folder. When a PDF file is created a copy will go into both this <I and> the Collection's PDF folder.\n",

 "<T PS><S PDF Page Size>\n",

 "This section allows you to specify the output page size for the PDF file in points (72/inch), inches or millimeters. The default size is A4 (297mm x 210mm). As an example, I use a Samsung Galaxy Note Pro 12.2 which has a screen size of 263mm x 164mm which is slightly smaller than A4 and therefore I had to reduce the various text sizes by 2 points to fit the same lines onto this page size.\n",

 "<P  Edit Media > ",
 "<M>This button brings up a small window that allows you to delete or create a new media type or just edit the media height and/or width. Deleting a Media type happens immediately you select <R OK> in the confirmation box. Editing the Media Name causes a new type of Media to be created.\n",

 "<P Print Media > ",
 "<M>This allows you to specify the Media size and fonts to be used when printing as opposed to the Media size/fonts you use for PDF generation for use on a tablet.\n",

 "<T FO><S Fonts - Colour and Size>\n",
 "This section allows you to define the fonts, their colour, size, weight (bold) and slant (italic), used for the various parts of the PDF and editor. The small (coloured) square to the left of the font name is a button that will let you define the colour that particular font will be displayed in. (See the separate section below that describes the colour editor)",
 "The <R Choose> button gives you access to all the available fonts.\n",

 "<T BC><S Background Colours>\n",
 "A Comment, Highlight, Title, Verse, Chorus, Bridge or Tab section can all have their background colour defined using these buttons.\n",

################

 "<T MU><H Miscellaneous\n>",
 "<V5>",

 "Normally, there would be a Menu bar at the top of the program window on Windows or at the top of the screen on Mac. However, it appears that the Mac implementation is busted and causes Perl to crash either when opening or when closing a secondary window from a menu selection. Therefore I decided to make what would have been the Chordy Menu items available as a number of buttons on a separate Tab:\n",

###
 "<T Mf><S File>\n",

 "<P  View Error Log > ",
 "<M>Lists the contents of the Error Log in a text window.",
 "<V5>",
 "<P  Clear Error Log > ",
 "<M>Removes all content from the Error Log.",
 "<V5>",
 "<P  Delete Pro Backups > ",
 "<M>Every time a ChordPro file is edited a numbered backup file is created. This button will arbitrarily delete all backups!",
 "<V5>",
 "<P  Delete Temp PDFs > ",
 "<M>Every time a PDF file is created it is placed in a <B Temp> folder. This button will clear the <B Temp> folder",
 "<V5>",
 "<P  View Release Notes > ",
 "<M>Does what it says. The latest Release is at the top of the page.\n",
###
 "<T Mo><S Options>\n",

 "<P  Edit Sort Articles > ",
 "<M>When listing ChordPro files you can elect to ignore any leading Articles - typically 'a', 'an' and 'the'. In practice, this option will ignore <I ANYTHING> at the beginning of a file name as long as it's followed by a space!",
 "<V5>",
 "<P  Edit Options File > ",
 "<M>If you don't know how Perl data structures are organised, this option enables you to edit the current Collection's Option file and screw things up completely!\n",

###
 "<T Ma><S Appearance>\n",

 "<s Colours> ",
 "<M>Allows you to change the Foreground and Background colours for Push and Menu buttons, Lists, Entry and Message boxes. Also lets you specify the Background colour for all the windows.\n",

 "<s Fonts> ",
 "<M>All buttons and lists can be displayed in \"Normal\" or \"<B Bold>\" text.\n",

 "<T Co><S Commands>\n",

 "<M>Normally the name of the ChordPro file will be appended to any of the commands. If you have a command that needs arguments <I after> the file name you can put the directive \%FILE\% into the Command string and this will automagically be replaced with the file name when executed.\n",

 "<s View PDF> ",
 "<M>The PDF file will always be created as a temporary file and this command enables you to view it. The default is to use Adobe's Acrobat Reader on Linux (on a Mac you will need to install it) and SumatraPDF on Windows.\n",

 "<s Print PDF> ",
 "<M>Command line used to print a PDF file. The default on Windows is to use the supplied app SumatraPDF and to send the output to the default system printer. Look for Sumatra documentation on the WEB if you want to play around with it.\n",

 "<T Sd><P  Save as Default > ",
 "<M>Saves the current Commands into a configuration file which will be read in the next time Chordy is started.",
 "<V5>",
 "<T Ld><P  Load Defaults > ",
 "<M>If you've previously Saved Commands, this will load those settings. This happens every time you start Chordy but is an easy way to undo any temporary changes you may have tried.",
 "<V5>",
 "<T Rd><P  Reset all Defaults > ",
 "<M>Chordy has a default list of Commands that you see the first time it is run. These can be retrieved using this button. Be aware that you then need to do a <R Save as Default> to make the change permanent.\n",

################

 "<T CE><H Colour Editor\n>",
 "<V5>",

 "In the colour editor you get 3 sliders that go from 0 to 255 for each primary colour where 0 is no colour and 255 is lots. The resulting mix is shown in a box on the right of the window. This box can have both the background and foreground colours changed but what will be used depends on what mode the editor is in (see the heading top right).",
 "Below the sliders is an entry area where you can modify the Hex values for a given colour. If a colour matches one of those listed on the left, that name will appear in this entry box.\n",
 "Below this are three buttons which give you quick access to the current Chorus, Highlight and Comment colours.",
 "The \"My Colours\" box gives you the ability to mix and save 16 different colours you might want to use on a regular basis. Clicking on one of the 16 buttons will set that fore/back-ground colour. If you then change the colour with the sliders, you can change the selected colour swatch with the <R Set Colour> button. These colours are only saved if you hit the <R OK> button.\n",

################

 "<T CD><H ChordPro Files & Directives\n>",
 "<V5>",

 "<R See the Editor's Help for a full description of all available directives.>\n",

 "The basic layout of a ChordPro file is lines of lyrics with chords embedded - for example:\n",
 "<c     [D]Amarillo By [F#m]Morning, [G]Up from San An[D]tone.>\n",
 "You'll note that each chord is enclosed in a pair of [ ] brackets. When converted to PDF the chords will appear above the appropriate lyric so the final D will appear above the 't' of Antone. It's more usual to write the lyric as An-[D]tone for readability.\n",
 "<c       D           F><U #m><c       G              D> ",
 "<c       Amarillo By Morning, Up from San An-tone.>\n",
 "The only restriction is that the first character after the opening [ must be an upper case letter between A and G inclusive if it is to be recognised as a legitimate chord. This letter can be optionally followed by a 'b' to indicate a flat or a # to indicate a sharp. <I Anything> else that follows will be printed in the PDF on the same line as the chords. This does mean that you can have a line in the ChordPro file that has NO lyrics and looks like this:\n",
 "<c     [C][      ][D][      ][E][      ][F]>\n",
 "    which will print as:\n",
 "<c     C      D      E      F>\n",
 "It also enables you to put (sort of) playing directives into a line of lyrics, for example:\n",
 "<c     [N/C]Throughout the [(What chord)]days, Our true love [A]ways>\n",
 "will print as:\n",
 "<c     N/C            (What chord)        A> ",
 "<c     Throughout the days, Our true love ways>\n",
 "Where the <c N/C> indicates \"No Chords\" ie Don't play anything. Note also that all of <c (What chord)> gets printed above the lyrics.",
 "Obviously, this only works where the first character is <I not> A to G :-) Even then it's not a problem until you transpose the piece at which point your spelling takes a dive because the first A to G will get shifted to the new key!\n",

 "Chordy also accepts augmented chords like [C/G] - both parts of the chord will be transposed if required. In the final PDF or printout, anything that makes up a legitimate chord definition will have the major base printed in the standard font and anything which modifies the major chord will be printed as a superscript (smaller font and raised above the text base line). If a space is encountered, the font will immediately revert to the standard size:\n",
 "<c     [D#]Some lyrics, [C/G]Lots more [G#m7 softly]lyrics>\n",
 "Displays as:\n",
 "<c     D><U #><c            C/G       G><U #m7><c  softly> ",
 "<c     Some lyrics, Lots more lyrics>\n",
 "The spec. for ChordPro defines quite a number of directives that can be embedded in the ChordPro file. This app only handles a specific subset of the directives but it provides extra functionality over the basic set. Most (but not all) directives have a short and a long form shown as <s {short|long: ...}>. Each directive must appear as the first (and only) text on any given line. You can embed comments into a ChordPro file by placing a '#' as the first character on a line followed by any text. This text will not appear on any output created using the ChordPro file.\n\n",
]);
  }
  $win->show();
  $win;
}

1;
