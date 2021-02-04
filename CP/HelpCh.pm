package CP::HelpCh;

use CP::Global qw/:FUNC :XPM/;
use CP::Help;

sub help {
  makeImage("checkbox", \%XPM);
  my $win = CP::Help->new("Chordy Help");
  return if ($win eq '');
  $win->add(
[
 "<O TO:H: Chordy > ",
 "Takes a standard(ish) ChordPro text file and converts it to a PDF file with the chords arranged above the lines of lyrics. Chordy can also transpose the music key, either permanently or just for the current PDF creation. Optionaly, you can have the chords shown at the top of the first page or all pages.",
 "Chordy works with independent sets of files called <R Collections>. Each Collection has its own set of ChordPro and PDF files and its own set of configuration options.",
 "In the applications main display you have 3 tabs:",
"<R Chordy PDF Generator> is where you get to convert your ChordPro files into a PDF file and/or Transposed etc.",
"<R Setlists> allows you to create/modify/delete Setlists and is also where you select one or more ChordPro files you want to edit and/or create PDFs.",
"<R Configuration Options> has the various settings used in each Collection.\n",

 "<O To:H:Menus>",
 "<V5>",
 "<O MF:S:File>",
 "<V1>", 
 "<O Mof:s: Open File(s)>",
 "<O Mfs:s: From Setlist>",
 "<O Mnc:s: New ChordPro>",
 "<O Mic:s: Import ChordPro>",
 "<V1>",
 "<O MFe:N: Export> ",
 "<O MFe:s:    One/All ChordPro>",
 "<O MFe:s:    One/All PDF>",
 "<V1>",
 "<O MFm:N: Mail> ",
 "<O MFm:s:    One/All ChordPro>",
 "<O MFm:s:    One/All PDF>",
 "<V1>",
 "<O Mc:s: Sync Collection>",
 "<O Mx:s: Exit>",
 "<V5>",
 "<O ME:S:Edit>",
 "<V1>",
 "<O MEo:s: Chord Editor>",
 "<O MEo:s: Collections>",
 "<O MEo:s: PDF Page Size>",
 "<O MEo:s: Sort Articles>",
 "<O MEo:s: Options File>",
 "<V5>",
 "<O MO:S:Options>",
 "<V1>",
 "<O MOp:N: PDFs> ",
 "<O MOp:s:    View>",
 "<O MOp:s:    Create>",
 "<O MOp:s:    Print>",
 "<V1>",
 "<O MOl:N: Lyrics> ",
 "<O Mlc:s:    Center Lyrics",
 "<O Mll:s:    Lyrics Only>",
 "<O Mlg:s:    Group Lines>",
 "<O Mlb:s:    1/2 Ht Blank Lines>",
 "<V1>",
 "<O Mol:s: Line Spacing>",
 "<V1>",
 "<O Moh:N: Highlight/Comment> ",
 "<O Moh:s:    Full line>",
 "<O Moh:s:    Border Relief>",
 "<O Moh:s:    Border Width>",
 "<V1>",
 "<O Moi:s: Ignore Capo Directives>",
 "<O Mon:s: No Long Line warnings>",
 "<O Mos:s: Show Labels>",
 "<O Mob:s: Label Background %>",
 "<V1>",
 "<O Moa:N: Appearance> ",
 "<O Mac:s:    Colours - Tabs Window Button Menu Entry List Message>",
 "<O Maf:s:    Fonts - Normal/Bold>",
 "<O Map:s:    Copy to all Collections>",
 "<O Mad:s:    Default Appearance>",
 "<V2>",
 "<O Mod:s: Defaults>",
 "<V5>",
 "<O MS:S:Misc>",
 "<V1>",
 "<O Mve:s: View Error Log>",
 "<O Mce:s: Clear Error Log>",
 "<O Mvr:s: View Release Notes>",
 "<O Mdc:s: Delete ChordPro Backups>",
 "<O Mdp:s: Delete Temporary PDFs>",
 "<O Msc:s: Commands>",
 "<V5>",
 "<O MH:S:Help>",
 "<V1>",
 "<O Mhh:s: Help>",
 "<O Mha:s: About>",
 "<V5>",
 "<H Chordy Tabs\n>",
 "<V5>",
 "<O Ch:S:Chordy PDF Generator>",
 "<V1>",
 "<O CP:s: ChordPro File(s)>",
 "<O PD:s: PDFs>",
 "<O SS:s: Single File>",
 "<O Op:s: PDF Options>",
 "<O DI:s: Chord Diagrams>",
 "<V5>",
 "<O SL:S: Setlists>",
 "<V1>",
 "<V5>",
 "<O FB:S:Configuration Options>",
 "<V1>",
 "<O CL:s: Collection>",
 "<O FO:s: PDF Fonts - Colour and Size>",
 "<O BC:s: PDF Sections Background Colours>",
 "<O PS:s: PDF Page Size>",
 "<V5>",
 "<O CE:S:Colour Editor>",
 "<V5>",
 "<O CD:S:ChordPro Files & Directives>",
 "<V5>",

######
 "<V10>",
 "<V2#000000>",
 "<V5>",
 "<V10>",
######
 "<T MF><H File Menu\n>",
 "<V5>",
 "<T Mof><s Open File(s)\n>",
 "<M>Opens the ChordPro browser which allows you to select one or more files contained in the current Collection's ChordPro folder (see the section on Folders and Commands).\n",
 "<V2>",
 "<T Mfs><s From Setlist\n>",
 "<M>Lets you pull in a list of files from a pre defined Setlist.\n",
 "<V2>",
 "<T Mnc><s New ChordPro\n>",
 "<M>Enables you to create a new ChordPro file - enters the Editor with the <R Title> directive initialised.",
 "<V2>",
 "<T Mic><s Import ChordPro\n>",
 "<M>Opens a File Select dialogue window. Any selected ChordPro files will be copied into your Collection's <B Pro> Folder.",
 "<V2>",
 "<T MFe><s Export\n",
 "<s    One/All ChordPro\n>",
 "<s    One/All PDF\n>",
 "<M>Lets you Export <R One> or <R All> ChordPro or PDF files from your Collection's <B Pro> or <B PDF> Folder to anywhere you choose. The <R One> buttons expects one of the files in the list to be selected otherwise it complains. The <R All> buttons ignore any selection and acts as you'd expect on all listed files.",
 "<M>Where the action is for PDF files, this assumes that the PDF files have alreay been created from the associated ChordPro file. If one or more PDFs have not been created you will get a list of those that have and those that have not been exported.",
 "<V2>",
 "<T MFm><s Mail\n>",
 "<s    One/All ChordPro\n>",
 "<s    One/All PDF\n>",
 "<M>As above - lets you Mail <R One> or <R All> <B Pro> or <B PDF> files from your Collection's <B Pro> or <B PDF> Folder. The same proviso applies for PDF files as above.",
 "<V2>",
 "<T Msc><s Sync Collection\n>",
 "<M>Compares the contents of a source and destination folder and syncronises them such that the destination matches the source.",
 "<V2>",
 "<T Mex><s Exit\n>",
 "<M>Does what it says - exits from Chordy.",
 "<V5>",

######
 "<T ME><H Edit Menu\n>",
 "<V5>",
 "<T MEe><s Chord Editor\n>",
 "<M>Opens a window that lets you add/modify chords for a chosen instrument. In the release version of Chordy, only a selection of guitar chords are defined.",
 "<V2>",
 "<T MEc><s Collections\n>",
 "<M>Opens a window that lets you Modify/Add/Delete/Rename a Collection.",
 "<V2>",
 "<T MEp><s PDF Page Size\n>",
 "<M>When you create a PDF from a ChordPro file it's page size is taken from the Media type associated with the current Collection. With this window you can specify which media you want associated with a Collection. You can create new Media specifications (ie. for a new tablet) and Modify/Rename/Delete an existing Media type.",
 "<V2>",
 "<T MEs><s Sort Articles\n>",
 "<M>The various lists of ChordPro files can be sorted alphabetically (as well as by date modified). This mini-editor lets you specify leading Articles that will be ignored for the purpose of sorting. For example: a file named \"The Letter.pro\" will ignore \"The\" and will place the file in the list with filenames starting with \"L\".",
 "<V2>",
 "<T MEo><s Options File\n>",
 "<M>Open a text editor with the contents of the Options File. If you don't know how to program in Perl you could screw Chordy up if you get it wrong!",
 "<V5>",

######
 "<T MO><H Options Menu\n>",
 "<V5>",
 "<T MOp><N PDFs\n>",
 "<s   View\n>",
 "<s   Create\n>",
 "<s   Print\n>",
 "<M>You can elect to <R View>, <R Create> and/or <R Print> all listed ChordPro files or just a single selected file.\nThe viewer is <B SumatraPDF> on Windows systems (installed with Chordy), <B Preview> on Mac and <B acroread> on Linux.",
 "<V2>",
 "<T MOl><N Lyrics\n>",
 "<T Mlc><s   Center Lyrics\n>",
 "<M>By default, the Lyrics, Highlights, Comments etc. are printed left justified (ie against the left side of the page). Turning this option on will center all text on each page.",
 "<V2>",
 "<T Mll><s   Lyrics Only\n>",
 "<M>Basically does not display <I any> of the chords but everything else is displayed as it normally would be ... really only usefull to give to the vocalist :)",
 "<V2>",
 "<T Mlg><s   Group Lines\n>",
 "<M>Chordy will always ensure a line of Lyrics and Chords are on the same page. This option allows you to apply the same to any number of lines that are separated by a blank line, or a <R Verse>, <R Chorus> or <R Bridge> directive. This can be a combination of Lyrics, Highlighted or any Comment variation. As long as there is no blank line they will all be moved onto a new page if they would not fit on the current page. The only time this is aborted is if the collection of lines is larger than the page size - this will turn the <R Group> option off for the rest of file processing.",
 "<V2>",
 "<T Mlb><s   1/2 Ht Blank Lines\n>",
 "<M>Any blank lines in the ChordPro file will only use 1/2 as much verticle space in the PDF. This may make the PDF more compact at the possible expense of readability.",
 "<V5>",
 "<T Mol><s Line Spacing\n>",
 "<M>Determines the spacing between lines. This does not affect the positioning of chords above the lyrics. I usually use a value of 1 or 2 for lyrics + chords and 4 or 5 for just lyrics.",
 "<V5>",
 "<T Moh><N Highlight/Comment\n>",
 "<s   Full line\n>",
 "<M>The text normally has a background colour <I just> around the text. This option extends the background to cover the whole line.",
 "<V2>",
 "<s   Border Relief\n>",
 "<M>The text can optionally have a coloured border placed around it with a Relief of <R raised>, <R sunken> or <R flat>. The only exception is the <R Comment Box> directive which will <I always> show with a 1 point black border.",
 "<V2>",
 "<s   Border Width\n>",
 "<M>This option defines the width of the applied border. Setting this value to 0 will disable any border.",
 "<V5>",
 "<T Moi><s Ignore Capo Directives\n>",
 "<M>If there is a <R Capo> directive in the ChordPro file, Chordy will transpose all chords in the file (except for the <R Key> directive). This option ignores the directive and shows the chords as written in the file but will still show the <R Capo> setting in the PDF but with \"(ignored)\" after it.",
 "<V2>",
 "<T Mon><s No Long Line warnings\n>",
 "<M>Chordy normally bleats about each (and every) lyric line it finds that is too long to fit on one line on the page. This option stops that and just shows one generic error at the end of the run.",
 "<V2>",
 "<T Mos><s Show Labels\n>",
 "<M>Any of the Verse, Chord, Bridge or Tab sections can have a <R Label> associated with it. This option allows you to turn the Labels on or off.",
 "<V2>",
 "<T Mob><s Label Background %\n>",
 "<M>If Labels are displayed they will have a background which is a shade of the sections background. This shade will be a percentage shift lighter (negative values) or darker (positive values) by this ammount.",

 "<V2>",
 "<T Moa><N Appearance\n>",
 "<T Mac><s    Colours - Tabs Window Button Menu Entry List Message\n>",
 "<M>Lets you specify the Background colour for all the above elements plus you can also change the Foreground colours for Push and Menu buttons, Lists, Entry and Message boxes.",
 "<V2>",
 "<T Maf><s    Fonts - Normal/Bold\n>",
 "<M>All buttons and lists can be displayed in \"Normal\" or \"<B Bold>\" text.",
 "<V2>",
 "<T Map><s    Copy to all Collections\n>",
 "<M>The current colour definitions will be copied to all Collection Options.",
 "<V2>",
 "<T Mad><s    Default Appearance\n>",
 "<M>Resets all colour definitions to their original default values.",
 "<V5>",

######
 "<T MS><H Misc Menu\n>",
 "<V5>",
 "<T Mve><s View Error Log\n>",
 "<M>Lists the contents of the Error Log in a text window.",
 "<V2>",
 "<T Mce><s Clear Error Log\n>",
 "<M>Removes all content from the Error Log.",
 "<V2>",
 "<T Mvr><s View Release Notes\n>",
 "<M>Shows the Release Notes in a text window. The latest Release is at the top of the page.",
 "<V2>",
 "<T Mdc><s Delete ChordPro Backups\n>",
 "<M>Every time a ChordPro file is edited a numbered backup file is created. This button will arbitrarily delete all backups!",
 "<V2>",
 "<T Mdp><s Delete Temporary PDFs\n>",
 "<M>Every time a PDF file is created it is placed in a <B Temp> folder. If the action is to create a new PDF file it will then be <I copied> to the <B PDF> folder. This button will clear the <B Temp> folder.",
 "<V2>",
 "<T Msc><s Commands\n>",
 "<M>Normally the name of the ChordPro file will be appended to any of the commands. If you have a command that needs arguments <I after> the file name you can put the directive \%FILE\% into the Command string and this will automagically be replaced with the file name when executed.",
 "<V5>",
 "<s   View PDF> ",
 "<M>The PDF file will always be created as a temporary file and this command enables you to view it. The default is to use <B SumatraPDF> on Windows systems (installed with Chordy), <B Preview> on Mac and <B acroread> on Linux.",
 "<V2>",
 "<s   Print PDF> ",
 "<M>Command line used to print a PDF file. The default on Windows is to use the supplied app <B SumatraPDF> and to send the output to the default system printer. Look for Sumatra documentation on the WEB if you want to play around with it. On Mac and Linux the default is to use <B lpr>.",
 "<V5>",

######
 "<T MH><H Help Menu\n>",
 "<V1>",
 "<T Mhh><s Help\n>",
 "<M>I know you're going to find it hard to believe, but this button gets you here!",
 "<V2>",
 "<T Mha><s About\n>",
 "<M>Shows you the current Release Number.",
 "<V5>",

######
 "<V10>",
 "<V2#000000>",
 "<V5>",
 "<V10>",
######

 "<T Ch><H Chordy PDF Generator Tab\n>",
 "<V5>",

 "<T CP><S ChordPro File(s)> ",
 "<M>These are files ending with a <B .pro> extension. The <R Browse> button allows you to select one or more files contained in the ChordPro folder (see the section on Folders and Commands).\nThe <R From Setlist> button lets you pull in a list of files from a pre defined Setlist.\n",

###
 "<T PD><S PDFs> ",
 "<M>You can elect to <B View>, <B Create> and/or <B Print> all listed ChordPro files or just a single selected file.\nThe viewer is <B SumatraPDF> on Windows systems (installed with Chordy), <B Preview> on Mac and <B acroread> on Linux. Whenever Chordy is creating a PDF, a small progress window will appear below the File List showing you which file is being worked on.",
 "The <R Single Song> button will <B View/Create/Print> a PDF file for the one selected ChordPro file.\nThe <R All Songs> button will <B View/Create/Print> a PDF file for each ChordPro file in the list unless the <R Single PDF> checkbox is active in which case a single PDF file will be created containing all the songs in the order shown in the ChordPro file list.\n",

###
 "<T SS><S Single File> ",
 "<M>This section allows you to operate on ONE selected ChordPro File and perform various actions on it:\n",

 "<P  Edit > ",
 "<M>Opens the selected file in the <B CPgedi> Editor.\n",

 "<P  Rename >  <P  Clone >  and  <P  Delete > ",
 "<M>Does what it says on the button :)\n",

 "<P  Transpose > ",
 "<M>Unlike when you create a PDF (see PDF Options below), this will permanently transpose all chords to the key defined in the option list and writes the new version back out to disk.\n",

###
 "<T Op><S PDF Options> ",

 "<X checkbox><s  Center Lyrics> ",
 "<M>By default, the Lyrics, Highlights, Comments etc. are printed left justified (ie against the left side of the page). Turning this option on will center all text on each page.\n",

 "<X checkbox><s  Lyrics Only> ",
 "<M>Basically does not display <I any> of the chords but everything else is displayed as it normally would be ... really only usefull to give to the vocalist :-)\n",

 "<X checkbox><s  Group Lines> ",
 "<M>Chordy will always ensure a line of Lyrics and Chords are on the same page. This option allows you to apply the same to any number of lines that are separated by a blank line, or a <R Verse>, <R Chorus> or <R Bridge> directive. This can be a combination of Lyrics, Highlighted or any Comment variation. As long as there is no blank line they will all be moved onto a new page if they would not fit on the current page. The only time this is aborted is if the collection of lines is larger than the page size - this will turn the <R Group> option off for the rest of file processing.\n",

 "<X checkbox><s  1/2 Height Blank Lines> ",
 "<M>Any blank lines in the ChordPro file will only use 1/2 as much verticle space in the PDF. This may make the PDF more compact at the possible expense of readability.\n",

 "<X checkbox><s  Highlight/Comment full line> ",
 "<M>Highlight and Comment text normally have a background colour <I just> around the text. This option extends the background to cover the whole line.\n",

 "<X checkbox><s  Ignore Capo Directives> ",
 "<M>This option stops Chordy from Transposing chords in a file if the <B {capo:n}> option is present in the file. However, it does <I NOT> alter the action of the <R Tanspose To> option.\n",

 "<X checkbox><s  No Long Line warnings> ",
 "<M>If it has to, Chordy will adjust the Lyric font size until it fits onto a line in which case it will display a warning to that effect. This option stops those warnings appearing - they can become anoying if you're processing a large number of files. View the error log - they're copied into that.\n",

 "<X checkbox><s  Show Labels> ",
 "<M>Any of the Verse, Chord, Bridge or Tab sections can have a <R Label> associated with it. This option allows you to turn the Labels on or off.\n",

 "<P  Line Spacing > ",
 "<M>Determines the spacing between lines. This does not affect the positioning of chords above the lyrics. I usually use a value of 1 or 2  for lyrics + chords and 4 or 5 for just lyrics.\n",

 "<P  Capo On > ",
 "<M>You can define the Capo position here. This setting will overide a <B {capo:n}> directive found in the ChordPro file. See the <B Directives> section <B Capo> for a description of how this affects the PDF output.\n",

 "<P  Transpose To > ",
 "<M>Allows you to select a key to transpose to. The app will scan the file for a {key:xx} directive (see below) to determine the original key. Failing that, it will take the first chord it finds as being the key. Be aware that if you View/Create/Print more than one ChordPro file, <B ALL> of them will be transposed to the same key!\n",

 "<s Force Sharp/Flat> ",
 "<M>These 2 options force all 'black' notes to be either sharps or flats. So, for example, if you want to transpose a piece to Eb, a chord that would have been Eb will be shown as D# if Force Sharp is in effect.\n",

 "<P  PDF Background > ",
 "<M>Pops up the colour editor and enables you to define a colour which will be placed over the whole PDF page background.\n",

 "<s Margins> ",
 "<M>This section lets you specify (in points) the Left, Right, Top and Bottom margins. These margins <I only> apply to any text on each page so backgrounds (behind the Title for example) will extend the whole width (and/or height) of the physical page.\n",

 ###
 "<T DI><S Chord Diagrams> ",

 "<M>This option set allows you to have an index of all the chords in the current song displayed at the top of the first page or the top of every page. Although the <R Instrument> button lets you select the type to display the chords for, only 6 string guitar chords are currently implemented. If you want to add chords to any of the available intruments, use the Chord Editor via the <R Edit> button.\n",

################

 "<T SL><H Setlists\n>",
 "<V5>",
 "This tab is split into an upper and a lower section.",
 "<V5>",
 "<S Upper Section> ",
 "The upper section shows (on the left) the currently available Setlists and to it's right a box which shows which Setlist is currently selected along with date/time information and to the right and below that, a number of buttons to manipulate the current Setlist:\n",
 "<P  New > ",
 "<M>Creates a new Setlist.",
 "<V5>",
 "<P  Rename > ",
 "<M>Renames the current Setlist.",
 "<V5>",
 "<P  Clone > ",
 "<M>Produces a copy of the current Setlist and gives it the new name.",
 "<V5>",
 "<P  Clear > ",
 "<M>Clears out all <R Name/Date/Time> fields and moves any <R Setlist Files> back to the <R Available Files> list.",
 "<V5>",
 "<P  Save > ",
 "<M>Saves any changes to the currently selected Setlist.",
 "<V5>",
 "<P  Delete > ",
 "<M>Deletes the currently selected Setlist after prompting.\n",
 "<P  Print > ",
 "<M>Puts a list of song titles onto one PDF page with a title that is the Current Set Name.",
 "<V5>",
 "<P  Import > ",
 "<M>Lets you import a Setlist (saved with the <R Export> function) into the current Collection.",
 "<V5>",
 "<P  Export > ",
 "<M>Lets you copy the current Setlist to another Collection or save it into a file.\n",

 "The date/time information for the current Setlist may be edited by clicking on the appropriate button - the only exception is the <R Name> field which is fixed (see <R Rename> above). The various fields are completed using pop-ups - the only buttons which are unique are the ones which increment/decrement the minutes - holding the left mouse button down while over the button will cause the minutes to change rapidly.\n",
 "<S Lower Section>",
 "<V5>",
 "This is a copy of the Browser pop-up and has a Sort/Search area and 2 list boxes:",
 "The Sort area allows you to sort either Alphabetically or by Date Modified and to reverse either sort mode.",
 "The Search area lets you type in a case insensitive string and will search the <R Available Files>. The search takes place as you type and throws up a message if no match is found. The <R Find Next> button does just that and will wrap back to the begining of the list if it fails to match when the end of the list is reached.\n",
 "<E><R Available Files> ",
 "<M>A list of all ChordPro files in the current collection. Double clicking a file will automatically transfer it to the <R Setlist Files>. The alphabet buttons below the <R Available Files> list enable you to quickly jump to entries starting with the appropriate letter.",
 "<E><R Setlist Files> ",
 "<M>All the files that either do, or will, make up the current Setlist. Below this list are 2 buttons:",
 "<E><R Clear> ",
 "<M>Moves all the <R Setlist Files> back into the <R Available FIles> list.",
 "<E><R Select for Editing> ",
 "<M>Will place the currently selected <R Setlist Files> into the <R ChordPro Files> list (on the 1st tab) and switch to that tab.\n",
 "The various arrow buttons move files between the 2 lists and allow you to change the order of the files in the Setlist.\n",

################

 "<T FB><H Configuration Options\n>",
 "<V5>",

 "<T CL><S Collection> ",
 "<M>A <B Collection> is a grouping of ChordPro, PDF and Tab files along with various configuration files.\nThe default Collection from the install is called (wait for it ....) <B Chordy> and lives in the <R C:/Users/[USERNAME]> folder on Windows or in <R \$ENV{HOME}> on Linux/Mac.\nNote the use of Unix path separators / instead of the Windows \\ - this is historical because the Perl programming language (which Chordy is written in) was developed for the Unix environment.\nYou cannot delete a Collection if it is the only one but if you create a second Collection you can delete the original Chordy Collection. This isn't 100% accurate as the global configuration files are always left in the <R C:/Users/[USERNAME]/Chordy> or <R \$ENV{HOME}/Chordy> folder but the Pro, PDF and Tab folders are emptied.\nThe Collection section shows you the current Collection name and the path to it. Clicking on the button allows you to change the current Collection.\n(The only Collection you aren't allowed to rename is the Chordy one)\n",

 "<s Common PDF Path> ",
 "<M>This allows any combination of Collections to share a PDF Folder. For example I have one Collection for a 4 string Bass and another for a 5 string but I want to have a common PDF folder. When a PDF file is created a copy will go into both this <I and> the Collection's PDF folder.\n",

 "<T FO><S PDF Fonts - Colour and Size> ",
 "This section allows you to define the fonts, their colour, size, weight (bold) and slant (italic), used for the various parts of the PDF and editor. The small (coloured) square to the left of the font name is a button that will let you define the colour that particular font will be displayed in. (See the separate section below that describes the colour editor)",
 "The <R Choose> button gives you access to all the available fonts.\n",

 "<T BC><S PDF Section Background Colours> ",
 "A Verse, Chorus, Bridge or Tab section can have their background colour defined using these buttons.\n",

 "<T PS><S PDF Page Size> ",

 "This section allows you to specify the output page size for the PDF file in points (72/inch), inches or millimeters. The default size is A4 (297mm x 210mm). As an example, I use a Samsung Galaxy Note Pro 12.2 which has a screen size of 263mm x 164mm which is slightly smaller than A4 and therefore I had to reduce the various text sizes by 2 points to fit the same lines onto this page size.\n",

 "<P  Media > ",
 "<M>This button brings up a small window that allows you to delete or create a new media type or just edit the media height and/or width. Deleting a Media type happens immediately you select <R OK> in the confirmation box. Editing the Media Name causes a new type of Media to be created.\n",

 "<P Print Media > ",
 "<M>This allows you to specify the Media size and fonts to be used when printing as opposed to the Media size/fonts you use for PDF generation for use on a tablet.\n",

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
 "You'll note that each chord is enclosed in a pair of [ ] brackets. When converted to PDF the chords will appear above the appropriate lyric so the final <B D> will appear above the 't' of Antone. It's more usual to write the lyric as An-[D]tone for readability.\n",
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
 "The spec. for ChordPro defines quite a number of directives that can be embedded in the ChordPro file. This app only handles a specific subset of the directives but it provides extra functionality over the basic set. Most (but not all) directives have a short and a long form shown as <s {short|long: ...}>. Each directive must appear as the first (and only) text on any given line. You can embed comments into a ChordPro file by placing a '#' as the first character on a line followed by any text. This text will not appear on any output created using the ChordPro file.\nYou may notice that some of the directives start with <B x_> - these are (my) non-standard directives. Chordy will recognise them with or without the leading <B x_>. The ChordPro standard says that any directives that start this way should be ignored if you are sticking rigidly to the standard and therefor should not cause another ChordPro handler to barf on them.\n\n",
]);
  $win->show();
}

1;
