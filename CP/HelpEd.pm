package CP::HelpEd;

use CP::Global qw/:OPT :FUNC :XPM/;
use CP::Help;

sub help {
  my($win) = shift;
  if ($win eq '') {
    makeImage("checkbox", \%XPM);
    foreach my $i (qw/bracket bracketsz braceclr bracesz/) {
      my $ht = Tkx::image_height($i) + 8;
      my $wd = Tkx::image_width($i) + 6;
      my $name = "H$i";
      my $subr = 'Tkx::'.$i.'_data';
      no strict 'refs';
      my $data = &$subr(-background => $Opt->{PushBG});
      Tkx::image_create_photo($name, -height => $ht, -width => $wd);
      $subr = 'Tkx::'.$name.'_put';
      &$subr(BLACK, -to => (0,0,$wd,$ht));
      &$subr($Opt->{PushBG}, -to => (1,1,$wd-1,$ht-1));
      &$subr($data, -to => (3,4));
    }
    $win = CP::Help->new("Editor Help");
    $win->add(
[
 "<O TO:H: Cpgedi - A ChordPro Editor > ",
 "This was Gedi (Gregs EDItor) Ver. 1.0, Copyright 1999 Greg London",
 "This program is free software. You can redistribute it and/or modify it under",
 "the same terms as Perl itself. Special Thanks to Nick Ing-Simmons.\n",
 "Modified by Ian Houlding (2015-19) for use with Chordy running under Tkx (Tcl/Tk).",
 "Not much (if any) of the original code survives :-)\n",

 "<O TO:H: Table Of Contents >",
 "<O OV:S:\nOverview>",

 "<O CM:S:\nCommands (top row)>",
 "<O LS:b: Line Spacing ><V1>",
 "<X open> <O OP:s:Open><V1>",
 "<X new> <O NW:s:New><V1>",
 "<X close> <O CL:s:Close><V1>",
 "<X save> <O SV:s:Save><V1>",
 "<X saveAs> <O SA:s:Save As><V1>",
 "<X text> <O AA:s:Editor Font><V1>",
 "<X textsize> <O Aa:s:Font Size><V1>",
 "<X textfg> <O Ac:s:Font Colour><V1>",
 "<X textbg> <O Ab:s:Editor Background><V1>",
 "<X chordL> <X chordR> <O Cl:s:Move Chord Left/Right><V1>",
 "<X exit> <O EX:s:Exit><V1>",
 "<X Find> <O FD:s:Find><V1>",
 "<X FindNext> <O FN:s:Find Next><V1>",
 "<X FindPrev> <O FP:s:Find Prev><V1>",
 "<X checkbox> <O IC:s:Ignore Case><V1>",

 "<O CM:S:\nCommands (bottom row)>",
 "<O TC:P: Text to ChordPro ><V1>",
 "<X cut> <X copy> <X paste> <O CT:s:Cut - Copy - Paste><V1>",
 "<X include> <O IN:s:Include><V1>",
 "<X wrap> <O WR:s:Wrap><V1>",
 "<X SelectAll> <O SL:s:Select All><V1>",
 "<X Unselect> <O DA:s:Deselect All><V1>",
 "<X Undo> <O UD:s:Undo><V1>",
 "<X Redo> <O RD:s:Redo><V1>",
 "<X settags> <O TS:s:Reformat Buffer><V1>",
 "<X chordU> <X chordD> <O Cu:s:Move Chord Up/Down><V1>",
]);
    if (OS ne 'aqua') {
      $win->add([
	"<X Replace> <O FR:s:Find & Replace><V1>",
	"<X ReplaceAll> <O RA:s:Find & Replace All><V1>",
		]);
    }

    $win->add(
[
 "<O CH:S:\nChords>",
 "<X bracket> <O BR:s:Chord Colour><V1>",
 "<X bracketsz> <O BS:s:Chord Size><V1>",
 "<X bracketoff> <O BO:s:Chord Offset><V1>",

 "<O DT:S:\nDirectives>",
 "<X braceclr> <O DR:s:Directive Colour><V1>",
 "<X bracesz> <O DS:s:Directive Size><V1>",
 "<O TT:s: title>","<V1>",
 "<O KY:s: key>","<V1>",
 "<O CA:s: capo>","<V1>",
 "<O TE:s: tempo>","<V1>",
 "<O NT:s: note>","<V1>",
 "<O HL:s: horizontal line>","<V1>",
 "<O VS:s: vertical space>","<V1>",
 "<O NP:s: new page>","<V1>",
 "<O CD:s: chord>","<V1>",
 "<O DF:s: define>","<V1>",
 "<O FT:s: chord/tab/text font>","<V1>",
 "<O FS:s: chord/tab/text size>","<V1>",
 "<O FC:s: chord/tab/text colour>","<V1>",
 "<O SG:s: Start/End of Grid>","<V1>",
 "<O SC:s: Start/End of Verse>","<V1>",
 "<O SC:s: Start/End of Chorus>","<V1>",
 "<O SC:s: Start/End of Bridge>","<V1>",
 "<O ST:s: Start/End of Tab>","<V1>",
 "<O CS:s: Verse/Chorus/Bridge/Tab>","<V1>",
 "<O HT:s: highlight>","<V1>",
 "<O CO:s: comment (plus italic & box)>","<V1>",
 "<O SB:s: start background>","<V1>",
 "<O EB:s: end background>","<V1>",
 "<O CC:s: colour selector>","<V1>",

 "<O GH:S:\nGoto & Help>",
 "<O GT:s: Go To>","<V1>",
 "<O HP:s: Help>",

 "<V 10>",
 "<V1#000000>",
 "<V 1>",
 "<V 1#000000>",
 "<V 10>",
 "<T OV><H Overview\n>",
 "<V 10>",
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
 "The spec. for ChordPro defines quite a number of directives that can be embedded in the ChordPro file. This app only handles a specific subset of the directives but it provides extra functionality over the basic set. There are also some non-standard directives which, by convention, start with <B x_> and should be ignored by any ChordPro handler that does not implement them. Within the Chordy environment you can leave the <B x_> out. Most (but not all) directives have a short and a long form shown as <s {short|long: ...}>. Each directive must appear as the first (and only) text on any given line. You can embed comments into a ChordPro file by placing a '#' as the first character on a line followed by any text. This text will not appear on any output created using the ChordPro file.\n",

 "The basic intention with this Editor was to make creating/editing ChordPro files easier. To this end the window is split into 5 main areas:\n",
 "<s Edit area (bottom right)> ",
 "Fairly obviously where all the text to be edited lives.\n",
 "<s Command Menu (top right)> ",
 "All the commands (Open/Close/Save etc.) are available via buttons and/or text boxes.\n",
 "<s Chords (top left)> ",
 "A series of buttons that let you enter chords (in ChorPro format) into the text area.\n",
 "<s Directives (middle left)> ",
 "Another set of buttons that insert <I Directives> into the text area.\n",
 "<s Counters, Goto & Help (bottom left)> ",
 "An area that shows you which line/column the cursor is at and a count of the number of lines in the total text.\n",

 "<T CM><H Commands (top row)\n>",
 "<V10>",
 "<T LS><P  Line Spacing > ",
 "<M>Increases or decreases the distance between lines to make it more (or less) readable.",
 "<V5>",
 "<T OP><X open> <s Open> ",
 "<M>Pops up a dialog showing all current ChordPro files.",
 "<V5>",
 "<T NW><X new> <s New> ",
 "<M>Asks for a name for the new file - no extension needed.",
 "<V5>",
 "<T CL><X close> <s Close> ",
 "<M>Closes the current edit session and wipes the text area clean. Prompts to save the file if any changes have been made.",
 "<V5>",
 "<T SV><X save> <s Save> ",
 "<M>Saves the current edit session to disk. If a name has not been previously defined you will prompted for one.",
 "<V5>",
 "<T SA><X saveAs> <s Save As> ",
 "<M>Saves the current edit session to a new file and leaves you editing the new file.",
 "<V5>",
 "<T AA><X text> <s Editor Font> ",
 "<M>Allows you to change the font used in the text area.",
 "<V5>",
 "<T Aa><X textsize> <s Font Size> ",
 "<M>Changes the size of the text area font.",
 "<V5>",
 "<T Ac><X textfg> <s Font Colour> ",
 "<M>Changes the colour of the text area font.",
 "<V5>",
 "<T Ab><X textbg> <s Editor Background> ",
 "<M>Lets you define the background colour of the text area.",
 "<V5>",
 "<T Cl><X chordL> <X chordR><s  Move chord Left/Right> ",
 "<M>Place the cursor on a chord definition and it will be highlighted. Clicking these buttons will move the whole chord definition Left or Right. Hitting the start or end of a line will move the chord to the previous/next line.",
 "<V5>",
 "<T EX><X exit> <s Exit> ",
 "<M>Same as <s Close> and then exits from the editor.",
 "<V5>",
 "<T FD><X Find> <s Find> ",
 "<M>Given that you have entered something into the <I Find:> box, the editor will search forward for the text - and wrap back to the top if necessary.",
 "<V5>",
 "<T FN><X FindNext> <s Find Next> ",
 "<M>Searches forward for the next occurance of the text.",
 "<V5>",
 "<T FP><X FindPrev><s  Find Prev> ",
 "<M>Searches backward for the previous occurance of the text.",
 "<V5>",
 "<T IC><X checkbox><s  Ignore Case> ",
 "<M>If checked, will do a case insensitive search.",
 "<V5>",

 "<T CM><H Commands (bottom row)\n>",
 "<V5>",
 "<T TC><P  Text to ChordPro > ",
 "<M>This button lets you convert a text file with chords above the lyrics into ChordPro format ie. with the chords surrounded by <B [> <B ]> and in front of the relevant lyric. There are a number of sites on the WEB that provide lyrics in this format and this saves an awful lot of tedious typing!",
 "<M>Simply cut and paste the text into the text area and hit the button.",
 "<V5>",
 "<T CT><X cut> <X copy> <X paste><s  Cut - Copy - Paste> ",
 "<M>Highlight some text and they do exactly what you'd expect.",
 "<V5>",
 "<T IN><X include><s  Include> ",
 "<M>This will pop up a dialog to select another file and it will be inserted into the text area at the current cursor position.",
 "<V5>",
 "<T WR><X wrap><s  Wrap> ",
 "<M>Lets you specify the point at which a line will wrap on the screen - word or character boundary or none.",
 "<V5>",
 "<T SL><X SelectAll><s  Select All> ",
 "<M>Highlights all text as a selection.",
 "<V5>",
 "<T DA><X Unselect><s  Deselect All> ",
 "<M>Removes any current selections.",
 "<V5>",
 "<T UD><X Undo><s  Undo> ",
 "<M>Undoes any typing/changes made to the text area. May well undo more than you expect.",
 "<V5>",
 "<T RD><X Redo><s  Redo> ",
 "<M>Any Undos are reinstated.",
 "<V5>",
 "<T TS><X settags><s  Reformat Buffer> ",
 "<M>Removes all formatting from all the text and then reformats it from start to end.",
 "<V5>",
 "<T Cu><X chordU> <X chordD><s  Move chord Up/Down> ",
 "<M>As with the Left and Right buttons (see above), the chord definition will move Up or Down one line.",
 "<V5>",
]);
    if (OS ne 'aqua') {
      $win->add([
      "<T FR><X Replace><s  Find and Replace> ",
      "<M>Given that there is some text in the <I Find:> box, the editor will search forward for the text and prompt you to replace it with whatever is in the <I Replace with:> box. You can type <I Y> or <I y> to confirm or <I N> or <I n> to skip the replacement.\n",

      "<T RA><X ReplaceAll><s  Replace All> ",
      "<M>Same as above except the editor will search for the next occurance and prompt you to replace the text. Typing anything other than the <I Yes/No> response will abort the Find/Replace.", "<V5>",
]);
    }
    $win->add(
[
 "<T CH><H Chords\n>",
 "<V10>",
 "<M>Clicking on any of the buttons will place the appropriate chord into the text area wherever the cursor is. If you hover over a chord you'll get a pop up that lists all the currently known chords with the selected base.",
 "<V5>",
 "<T BR><X bracket><s  Chord Colour> ",
 "<M>Changes the colour of all Chords displayed in the edit area.",
 "<V5>",
 "<T BS><X bracketsz><s  Chord Size> ",
 "<M>Changes the size that Chords are displayed at.",
 "<V5>",
 "<T BO><X bracketoff><s  Chord Offset> ",
 "<M>Because of the way text baselines are handled, Chords can appear below or above the lyric text baseline. This allows you to adjust the Chord baseline",
 "<V5>",

 "<T DV><H Directives\n>",
 "<V10>",
 "A ChordPro formatted file consists of lyrics and chords but can also include <I directives> that tell a formatting program how to display the information. <R Chordy> has most (but not all) of the ChordPro directives inplemented plus some variations - mainly to control colours.",
 "Each directive <B MUST> be the first and <B ONLY> item on any given line and is a directive (optionally with arguments) enclosed in <B {> <B }> braces.\n",
  "<T DR><X braceclr><s  Directive Colour> ",
  "<M>Changes the colour of all Directives displayed in the edit area.\n",

 "<T DS><X bracesz><s  Directive Size> ",
 "<M>Changes the size that Directives are displayed at.\n",

 "<T TT><s {t|title:text...}> ",
 "<M>Specifies the title of the song. It will appear centered at the top of each page. This overides any title generated by default from the file name.\n",

 "<T KY><s {key:xx}> ",
 "<M>Defines the music key. Flats are indicated using lower case B (b) and sharps are the usual #.\n",

 "<T CA><s {capo:X}> ",
 "<M>Will appear as <B Capo: X> below any Note - if there is one - otherwise it will be immediately below the heading area. Again, this will only be on the first page.\n",

 "<T TE><s {tempo:X}> ",
 "<M>Puts the text <B 'Tempo: xxx'> at the top of the first page just below the title.\n",

 "<T NT><s {note:text...}> ",
 "<M>This will appear immediately below the heading area on the left of the first page only.\n",

 "<T HL><s {x_hl|x_horizontal_line:height length colour}> ",
 "<M>THIS IS NOT A STANDARD ChordPro DIRECTIVE!",
 "<M>This will draw a horizontal line on the page. The default is 1 point (1/72 of an inch) high the width of the page and transparent. The actual values you can place after the ':' are one or more of:",
 "<M>     <B line height>, <B line length> and <B line colour> (each separated by a space).\nAll lengths are in points (72 per inch) and the colour is defined in either of the usual ways.\nIf there is just one number before a colour definition, it is taken as being the line height - the width being the default of the page width.\nAlthough this is designed to draw a line, if you leave out the colour value this directive will insert a vertical space into the page so, for example, {hl:18} will insert a blank line about 1/4\" high into the page. A more efficient way is to use the {vspace} directive - see below.\n",

 "<T VS><s {x_vs|x_vspace:height}> ",
 "<M>THIS IS NOT A STANDARD ChordPro DIRECTIVE!",
 "<M>This will insert <B height> points of vertical space into the page. The default (if <B height> is not specified) is 5 points (approx 1.75mm).\n",
 
 "<T NP><s {np|new_page}> ",
       "<s {npp|new_physical_page}> ",
 "<M>Forces a page break. (Chordy will always keep a pair of cord/lyric lines on one page.)\n",

 "<T CD><s {chord:xx...}> ",
 "<M>Will display a chord fingering layout and within Chordy is independent of the \"Chord Index\" selection.\nYou can specify as many chords as you like within the same directive, just separate each one with a space.\nA number indicating the first fret is displayed alongside the layout - NOTE: the fingerboard nut is NOT considered to be a fret. Above each string, an 'o' indicates an open string and an 'x' indicates an unplayed string.\nIf this directive is immediately followed by another <B {chord}> the next image will be displayed alongside the previous one. Seperating {chord} directives with a blank line will cause the chord after the blank line to be placed at the start of the next line.\n",

 "<T DF>",
 "<s {define:><I name> <I base-fret> <s x> <I frets> <s y y y y y y}> ",
 "<M>This directive defines a new chord fingering or will redefine an existing one. On its own it does nothing to the resulting PDF file unless a \"Chord Index\" is selected within Chordy or a {chord:} directive is used.\n\"name\" is a standard chord ie. Asus4, B(addE), B/F#\nThe words <I base-fret> and <I frets> are key words and should be entered verbatim.\nThe <I frets> entries start at the lowest string (bass E on a 6 string guitar) and can be '-', 'x' or 'X' for 'not played', '0' for an open string or a number (sort of) relative to the <I base-fret>. Not the way I would have designed the numbering but - hey - why have standards if you don't adhere to them!\nHere's a simple example of how it works - suppose you have a cord which only involves the bass E & A strings and is played by having your finger between the nut and the first fret (F) on the E string and between the 2nd and 3rd fret (C) on the A string. The <I base-fret> would be \"1\" and so would the first value in the <I frets> list. The second value would be 3. If you now want to redefine this chord such that the 3rd fret on the E string (G) is used, the <I frets> numbers stay the same but the <I base-fret> now becomes 3. So a <I frets> number of <B 1> is equal to the <I base-fret> when actually played - makes any sense?\nIf you are defining a chord for a 4 string instrument then only insert 4 <I frets> values instead of 6.\n",

 "<T FT><s {chordfont:...}> ",
       "<s {tabfont:...}> ",
       "<s {textfont:...}> ",
 "<M>If there is nothing after the <B :> (ie a blank directive) then the font will revert to it's default value.",
 "<M>The 3 <I xxxx><s font> directives are standard in ChordPro but have been enhanced in this version. The normal ChordPro also has {chordsize:xx}, {tabsize:xx} and {textsize:xx} directives (see below) but these have been incorporated into these enhanced <I xxxx><s font> directives.\nThe syntax to use is:\n<R   {xxxxfont:FontName Size Weight Slant}>\nWhere:\n<R   FontName> must be enclosed in <R {}> braces if it contains spaces ie:",
 "<R     {xxxxfont:{Times New Roman} 14 bold italic}> ",
 "<R   Size> must be a number between <R 6> and <R 66> (which is HUGE!)",
 "<R   Weight> is either <R bold> or <R normal>.",
 "<R   Slant> is either <R italic> or <R roman>.\n",

 "<M>You can have one or more of the entries but they MUST be in the order shown above - so all the following are valid examples:",
 "<R       {xxxxfont:{Times New Roman}}>     (This has the same effect as the standard ChordPro directive) ",
 "<R       {xxxxfont:{Times New Roman} 14}> ",
 "<R       {xxxxfont:{Times New Roman} 14 bold}> ",
 "\nWhat are not valid (and will be ignored) are entries like this:",
 "<R       {xxxxfont:Times New Roman 14}> - <R Times> will be taken as the font name and <R New> should be the size but isn't a number.",
 "<R       {xxxxfont:{Times New Roman} bold}> - the font size (a number) should come after the font name.\n",

 "<T FS><s {chordsize:...}> ",
       "<s {tabsize:...}> ",
       "<s {textsize:...}> ",
 "<M>These change the size of the appropraite font. A blank directive reverts the size (and only the size) to it's default value.\n",

 "<T FC><s {chordcolour:...}> ",
       "<s {tabcolour:...}> ",
       "<s {textcolour:...}> ",
 "<M>These change the foreground colour of the appropriate font. As above, a blank directive reverts the font colour to it's default value.\n",

 "<T SG><s {start_of_grid:...}> ",
       "<s {end_of_grid}> ",
 "<M>For a full explanation see:",
 "<M>      https://github.com/ChordPro/chordpro/wiki/Directives-env_grid",
 "<M>The <I start> directive can contain one or more of the following:",
 "<R       X>\t\tThe number of cells (measures x beats) on one line (defaults to 4 beats/measure).",
 "<R       MxB>\t\tThe number of Measures and Beats/Measure on one line.",
 "<R       L+(X/MxB)>\t\tThe number of cells in the left margin plus the cell count as above.",
 "<R       L+(X/MxB)+R>\t\tThe number of cells in the left & right margins plus the cell count as above.",
 "<M>Note the use of <I x> and <I +> between components and also that there are <I NO> spaces between any of the numbers.",
 "<M>The left margin of a grid line can contain text which will overide any <R L> component above.",
 "<M>This is also true for the right margin - the margins will be adjusted to accomodate the longest section of text.",
 "<M>You can follow any of the above with a space and then <I ANY> text which will be displayed above the Grid as if it were a <R {comment:...}> directive.",
 "<M>A Grid line may contain any of the following:",
 "<R       |>\t\tBar separator.",
 "<R       ||>\t\tSection separator.",
 "<R       |:>\t\tStart of repeat.",
 "<R       :|>\t\tEnd of repeat.",
 "<R       :|:>\t\tEnd of a repeat and start of another one.",
 "<R       |.>\t\tEnd of Bar line.",
 "<R       .>\t\tCell marker where \"a cell does not need to contain a chord\" (whatever that means!)",
 "<R       />\t\tCell marker (a chord is played)",
 "<R       %>\t\tRepeat the last Measure.",
 "<R       %%>\t\tRepeat the last 2 Measures.",
 "<M>So a Grid definition might look like the following:",
 "<R {start_of_grid 1+4x2+4}> ",
 "<c A    || G7 . | % .  |  %% .  | . .  |> ",
 "<c      | C7 .  | %  . || G7 .  | % .  ||> ",
 "<c      |: C7 . | %  . :|: G7 . | % . :| repeat 4 times> ",
 "<c Coda | D7 .  | Eb7  |   D7   | G7 . | % . |.> ",
 "<R {end_of_grid}> \n",
 
 "<T SC><s {sov|start_of_verse}> ",
       "<s {soc|start_of_chorus}> ",
       "<s {sob|start_of_bridge}> ",
       "<s {eov|end_of_verse}> ",
       "<s {eoc|end_of_chorus}> ",
       "<s {eob|end_of_bridge}> ",
  "<M>These should be placed immediately before and after any lyrics that form a verse, chorus or bridge section. You can then subsequently use just the {verse}, {chorus} or {bridge} directive on its own and the lyrics enclosed by the {soX}/{eoX} pair will be displayed.",
  "<M>The one enhancement to the standard ChordPro directive is that you can follow the directive with a numeric argument to indicate the verse/chorus/bridge number: {sov:1}",
  "<M>This is useful where (in this example) the first verse is later repeated and you can therefore use the directive {verse:1} to repeat that specific verse.\n",

 "<T ST><s {sot|start_of_tab}> ",
       "<s {eot|end_of_tab}> ",
 "<M>A Tab section is displayed verbatim and is usually displayed in a fixed pitch font. So assuming the Tab font is set at the default of Courier, this directive:",
 "<M>{start_of_tab}",
 "<M>G|4-24----|4-24----|--------|--------|",
 "<M>D|-4---424|-4---42-|4-242---|4-242---|",
 "<M>A|--------|-------4|-4---424|-4---424|",
 "<M>E|--------|--------|--------|--------|",
 "<M>{end_of_tab}\n",
 "<M>Would display as:",
 "<c G|4-24----|4-24----|--------|--------|> ",
 "<c D|-4---424|-4---42-|4-242---|4-242---|> ",
 "<c A|--------|-------4|-4---424|-4---424|> ",
 "<c E|--------|--------|--------|--------|> \n",
 "<M>As with the equivalent verse/chorus/bridge directives, the {sot} one can be followed with a numeric argument so that future {tab} directives can repeat a previously defined tab section.",
 "<M>Also worth mentioning is that Tab sections will <I ALWAYS> be kept together on one page so it's advisable to split a number of tab 'lines' inside individual {sot}/{eot} sections.\n",
 "<T CS><s {verse}> ",
       "<s {chorus}> ",
       "<s {bridge}> ",
       "<s {tab}> ",
  "<M>Display any lines of the song previously saved by the {soX}/{eoX} directives above. If you specify a colour, only this section will have that background.",
  "<M>As indicated above, a Chordy enhancement to this directive is the ability to specify a specific verse/chorus/bridge/tab section to repeat by having a numeric argument after the directive ie: {chorus:2}.",
  "<M>If you specify a verse/chorus/bridge/tab number (ie {verse:1}) and Chordy detects there are no lines of lyrics defined it will act as if you had just specified {verse}, {chorus}, {bridge} or {tab}.\n",
 
 "<T HT><s {highlight:text...}> ",
 "<M>Draws <Y  text >  using the Highlight font which by default is Bold+Italic and with a <Y  dayglo yellow > background.",
 "<M><R Note: >It would appear that this directive has been deprecated as it's no longer listed on the ChordPro Web site.\n",

 "<T CO><s {c|comment:text...}> ",
 "<T CO><s {ci|comment_italic:text...}> ",
 "<T CO><s {cb|comment_box:text...}> ",
 "<M>These 3 use the Comment font with the {ci:} using the Italic version (if available). The {cb:} version places an outlined box around the comment. By default, all 3 display with a <L pale blue background>\n",
 "<M>The chorus, highlight and comment directives can all be modified to change their background colour. This is done using an rgb (red,green,blue) format where you specify the ammount of each primary colour as a number between 0 and 255 where 0 is no colour and 255 is lots! So, for example, a pure green would be specified as 0,255,0 - white would be 255,255,255 and black would be 0,0,0. To use this mechanism in a directive just place the comma separated numbers as the last thing before the closing }. For example: {c:Some text255,0,255} will display <F  Some text > against a Fuchsia background - as if you would!! When this mechanism is used, the colour stays in effect until changed by another directive of the same class ie. chorus, highlight or comment.",
 "<M>An alternative to using the rgb format is to use the hexadecimal format. This takes the form of a '#' character followed by 3 bytes indicating the red, green and blue values. For example #FF00FF is maximum red (FF), no green (00), maximum blue (FF). This is the format returned by the Colour Selector - see below. The purple example above would be written as:",
 "      {c:Some text#FF00FF}\n",

 "<T SB><s {x_sbg|x_start_background:colour}> ",
 "<T EB><s {x_ebg|x_end_background}> ",
 "<M>ANOTHER NON-STANDARD ChordPro DIRECTIVE!",
 "<M>Placed before and after one or more lines of lyrics/chords will cause them to be displayed with the background colour defined in {sbg}. The colour can be defined either as an RGB value (see above) or with a leading '#' as a 3 byte hexadecimal number. The editor has a colour chooser that allows you to select a colour and supplies the correct string for you. The background colour is canceled by anything other than a line of lyrics/chords.\nBe aware that a line with just a single space character will NOT cancel the background colour and can be used to insert a (seemingly) blank line into a coloured section.\n",

 "<T CC><s Colour Selector> ",
 "<M>In the colour editor you get 3 sliders that go from 0 to 255 for each primary colour where 0 is no colour and 255 is lots. The resulting mix is shown in a box on the right of the window. This box can have both the background and foreground colours changed but what will be used depends on what mode the editor is in (see the heading top right).",
 "<M>Below the sliders is an entry area where you can modify the Hex values for a given colour. If a colour matches one of those listed on the left, that name will appear in this entry box.\n",
 "<M>Below this are three buttons which give you quick access to the current Verse, Chorus, Bridge, Highlight and Comment colours.",
 "<M>The \"My Colours\" box gives you the ability to mix and save 16 different colours you might want to use on a regular basis. Clicking on one of the 16 buttons will set that fore/back-ground colour. If you then change the colour with the sliders, you can change the selected colour swatch with the <R Set Colour> button. These colours are only saved if you hit the <R OK> button.\n",
 "<M>Beside the <s Colour Selector> button are 6 quick entry buttons for the current <R Highlight>, <R Comment>, <R Verse>, <R Chorus>, <R Bridge> and <R Tab> colours.\n",

 "<T GH><H Goto & Help\n>",
 "<V10>",
 "<T GT><P  Go To > ",
 "<M>Enter a line number into the text box and hit the button. The insert cursor will be placed at the start of that line.\n",
 "<T HP><P  Help > ",
 "<M>I know you'll find it hard to believe, but that's how you got here!",
]);
  }
  $win->show();
  $win;
}

1;
