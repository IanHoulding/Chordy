package CP::HelpTab;

use CP::Cconst qw/:OS/;
use CP::Global qw/:FUNC :XPM/;
use CP::Help;

sub help {
  my $win = CP::Help->new("Tab Help");
  return if ($win eq '');
  makeImage("scheckbox", \%XPM);
  $win->add(
[
 "<T CTO><O TO:H:Tab Editor>",
 "\nMy first pass at writing a Tab editor.\nAt some point I'll get round to writing the help section in full :)\n",
 "The editor is split vertically with the left half to display what the final PDF page will look like (more or less) and the right half to handle editing and some of the options.\n",

 " <O CTo:S:Menus>",
 "<V 5>",
 " <O CPD:S:PDF Page Display>",
 "<V 5>",
 " <O CEO:S:Page Editing & Options>",
 "<V 5>",
 " <O CBE:S:Bar Editor>",
 "<V 5>",
 " <O CE:S:Colour Editor>",

 "<V 10>",
 "<V 1#000000>",
 "<V 1>",
 "<V 1#000000>",
 "<V 10>",

#####################

 "<T CTo><O To:h:   Menus   >",
 "<V 10>",
 " <O MF:S:File>",
 "<V 1>",
 "  <O Mfo:s: Open Tab>",
 "  <O Mfn:s: New Tab>",
 "  <O Mfc:s: Close Tab>",
 "  <O Mfd:s: Delete Tab>",
 "  <l 2 100 #800000>",
 "<V 1>",
 "  <O Mfs:s: Save Tab>",
 "  <O Mfa:s: Save Tab As>",
 "  <O Mfm:s: Save, Make & Close>",
 "  <O Mfr:s: Rename Tab>",
 "  <O Mfe:s: Export Tab>",
 "  <l 2 100 #800000>",
 "<V 1>",
 "  <O Mfx:s: Exit>",
 "<V 5>",

 " <O ME:S:Edit>",
 "<V 1>",
 "  <O MEc:s: Collections>",
 "  <O MEm:s: Media>",
 "  <O MEf:s: Fonts>",
 "<V 5>",

 " <O MP:S:PDF>",
 "<V 1>",
 "  <O Mpv:s: View>",
 "  <O Mpc:s: Make>",
 "  <O Mpb:s: Batch Make>",
 "  <O Mpp:s: Print>",
 "  <l 2 100 #800000>",
 "<V 1>",
 "  <O Mps:s: Save, Make & Close>",
 "  <O Mpt:s: Save As Text>",
 "<V 5>",

 " <O MO:S:Options>",
 "<V 1>",
 "  <O Moi:s: Instrument>",
 "  <O Mot:s: Timing>",
 "  <O Mok:s: Set Key>",
 "  <O Mob:s: Bars/Stave>",
 "  <O Mos:s: String Spacing>",
 "  <O Mog:s: Stave Gap>",
 "  <O Moe:s: Edit Scale>",
 "  <O Mol:s: Lyric Lines>",
 "  <O Mop:s: Lyric Spacing>",
 "<V 5>",

 " <O MM:S:Misc>",
 "<V 1>",
 "  <O Mmv:s: View Error Log>",
 "  <O Mmc:s: Clear Error Log>",
 "  <O Mmr:s: View Release Notes>",
 "  <l 2 100 #800000>",
 "<V 1>",
 "  <O Mmd:s: Delete Tab Backups>",
 "<V 5>",

 " <O MH:S:Help>",
 "<V 1>",
 "  <O Mhh:s: Help>",
 "  <O Mha:s: About>",
 "<V 10>",

#####################

 "<T CPD><O PD:h:   PDF Page Display   >",
 "<V 10>",
 "  <O PO:s: Overview>",
 "<V 1>",
 "  <O PP:P: {{{ Prev Page ><V3>",
 "  <O PE:P: Edit Lyrics ><V3>",
 "  <O PN:P: Next Page }}} ><V3>",
 "<V 10>",

#####################

 "<T CEO><O EO:h:   Page Editing & Options   >",
 "<V 10>",

 " <O SL:S:Select>",
 "<V 1>",
 "  <O So:P: Collection ><V3>",
 "  <O Sm:P: Media ><V3>",
 "<V 5>",

 " <O TFN:S:File Options>",
 "<V 1>",
 "<O TFN:s: Tab File Name>",
 "<O PFN:s: PDF File Name>",
 "<O TI:s: Title>",
 "<O HN:s: Heading Note><V3>",
 "<V 5>",

 " <O EE:S:Edit>",
 "<V 1>",
 "  <O Ee:P: Edit Bar ><V3>",
 "  <O Ec:P: Clone Bar(s) ><V3>",
 "  <O Sc:P: Clear Selection ><V3>",
 "  <O Sb:P: Clear Bar(s) ><V3>",
 "  <O Sd:P: Delete Bar(s) ><V3>",
 "<V 5>",

 " <O CP:S:Copy/Paste>",
 "<V 1>",
 "  <O Ch:P: Copy ><V3>",
 "  <O Cb:P: Before ><V3>",
 "  <O Co:P: Over ><V3>",
 "  <O Cf:P: After ><V3>",
 "<V 5>",

 " <O BG:S:Background>",
 "<V 1>",
 "  <O Bs:P: Set ><V3>",
 "  <O Bc:P: Clear ><V3>",
 "<V 5>",

 " <O LY:S:Lyric>",
 "<V 1>",
 "  <O Lu:P: Shift Up 1 Line ><V3>",
 "  <O Ld:P: Shift Down 1 Line ><V3>",
 "<V 5>",

 " <O TR:S:Transpose>",
 "<V 1>",
 "  <O Ts:s: Semi-tones ><V3>",
 "  <O To:s: One String ><V3>",
 "  <X scheckbox><O Ta:s: Adjust Stings><V3>",
 "<V 5>",

 " <O MA:S:Margins>",
 "<V 5>",
]);

  if (OS eq "win32") {
    $win->add(
      [
       " <O TP:S:\Tab Player> ",
       "<V 5>",
      ]);
  }

  $win->add(
[
#####################

 "<V 5>",
 "<T CBE><O BE:h:   Bar Editor   >",
 "<V 10>",
 " <O Bo:S:Overview>",
 "<V 5>",
 " <O Be:S:Edit Buttons>",
 "<V 5>",
 " <O Bf:S:Fret Number/Rest>",
 "<V 5>",
 " <O Bs:S:Slide - Hammer>",
 "<V 5>",
 " <O Bb:S:Bend - Bend/Release>",
 "<V 5>",
 " <O Bp:S:Bar Options>",

 #####################

 "<V 10>",
 "<V 1#000000>",
 "<V 1>",
 "<V 1#000000>",
 "<V 10>",

 #####################

 "<T ES><H Menu Section\n>",
 "<V 10>",
 "<T MF><S File>",
 "<V 3>",
 "<T Mfo><s  Open Tab> ",
 "<M>Allows you to select a Tab file from the current Collection.",
 "<V 5>",

 "<T Mfn><s  New Tab> ",
 "<M>Prompts for a file name and creates a new Tab file.",
 "<V 5>",

 "<T Mfc><s  Close Tab> ",
 "<M>Closes the current Tab session and prompts for a Save if any changes have been made.",
 "<V 5>",

 "<T Mfd><s  Delete Tab> ",
 "<M>Deletes the current Tab.",

 "<l 2 100 #800000>",

 "<T Mfs><s  Save Tab> ",
 "<M>Saves the current Tab put keeps the edit session open.",
 "<V 5>",

 "<T Mfa><s  Save Tab As> ",
 "<M>Prompts for a new Tab name and Saves the current session to it and then opens the new Tab for editing.",
 "<V 5>",

 "<T Mfm><s  Save, Make & Close> ",
 "<M>Shortcut to perform each of the action in sequence.",
 "<V 5>",

 "<T RT><s  Rename Tab > ",
 "<M>Renames the current Tab and continues the edit session.",
 "<V 5>",

 "<T XT><s  Export Tab > ",
 "<M>Allows you to save the current session (with the current name) to a selectable folder.",

 "<l 2 100 #800000>",

 "<T EX><s  Exit> ",
 "<M>Quits Tab but prompts to Save any changes made.",
 "<V 10>",
####
 "<T ME><S Edit>",
 "<V 3>",
 "<T MEc><s  Collections> ",
 "<M>Pops up the Collection Editor.",
 "<M>The selected Collection can be <R Delete>d or <R Move>d - the <R Move> function is actually a <R Copy> unless the<X scheckbox><R Delete origial> box is checked.",
 "<M>Entering a name into the <R New Name> box lets you either create a <R New> Collection or <R Rename> the existing one.",
 "<M>The <R Common PDF Path> allows you to share a folder with Chordy for PDF files. Any PDFs created will be placed here <I as well as> in the Collections PDF folder.",
 "<V 1>",

 "<T MEm><s  Media> ",
 "<M>Lets you modify any of the Media types - essentially there to modify PDF page sizes. Internally, Tab uses <B points> for all measurements but you can enter <R Width> or <R Height> values in <b inches> or <B millimeters>.",
 "<M>As with <O MEc:K: Collections> above, the <R New Media Name> box lets you create a <R New> type of Media or <R Rename> the existing one.",
 "<V 1>",

 "<T MEf><s  Fonts> ",
 "<M>The Font Editor lets you change the Font, Colour, Weight and Slant for various items displayed in a Tab. Some Fonts allow the text and background colour to be changed - most only allow the text colour to be changed. You'll notice that you can select a Font to <R Bold> or <R Heavy> (or neither) - the <R Font Attributes> section lets you set how bold or heavy a Font is. The Font on the screen will not reflect these settings and will only display as <R Bold>. You'll have to <R View> the PDF to see the difference. The <R Italic> attribute lets you vary the slope angle of the Font - again, you can only see this in the PDF as the window display uses a fixed angle.",
 "<V 10>",
####
 "<T MP><S PDF>",
 "<V 3>",
 "<T Mpv><s  View> ",
 "<M>Creates a temporary PDF and displays it in the viewer.",
 "<T Mpv><s  Make> ",
 "<M>Makes a new PDF and stores it in the Collection's PDF folder.",
 "<T Mpv><s  Batch Make> ",
 "<M>The same as <R Make> but does it on a selected number of tab files.",

 "<T Mpv><s  Print> ",
 "<M>Creates a temporary PDF and prints it. Be aware that if your Media type is not <B A4> but your printer paper is, then the resulting printout will either be smaller than a page or will overflow a page, depending on the relevant sizes.",

 "<l 2 100 #800000>",

 "<T Mpv><s  Save, Make & Close> ",
 "<M>Performs the operations as a single sequence.",
 "<T Mpv><s  Save As Text> ",
 "<M>Creates an ASCII text version as a close approximation of the PDF output. Will probably need tweeking but better than nothing!",
 "<V 10>",
####
 "<T MO><S Options>",
 "<V 3>",
 "<T Moi><s  Instrument> ",
 "<M>Determines the number of strings per bar.",
 "<T Mot><s  Timing> ",
 "<M>Specifies the number of crotchets per Bar - currently only 2/4, 3/4 and 4/4 are implemented.",
 "<T Mok><s  Set Key> ",
 "<M>Does nothing other than define the Key for the Tab.",
 "<T Mob><s  Bars/Stave> ",
 "<M>Sets the number of Bars in each Stave (line of notes).",
 "<T Mos><s  String Spacing> ",
 "<M>Adjusts the spacing between each string in a Stave.",
 "<T Mog><s  Stave Gap> ",
 "<M>Adds extra space below a Stave.",
 "<T Moe><s  Edit Scale> ",
 "<M>Defines the magnification factor for the Bar Editor.",
 "<T Mol><s  Lyric Lines> ",
 "<M>The number of Lyrics lines displayed below each Stave.",
 "<T Mop><s  Lyric Spacing> ",
 "<M>Adds extra space below each Lyric line.",
 "<V 10>",
####
 "<T MM><S Misc>",
 "<V 3>",
 "<T Mmv><s  View Error Log> ",
 "<M>Displays the Error Log in a text window.",
 "<T Mmc><s  Clear Error Log> ",
 "<M>Removes everything from the current Error Log.",
 "<T Mmr><s  View Release Notes> ",
 "<M>Displays the Release Notes file in a text window.",
 "<l 2 100 #800000>",
 "<T Mmd><s  Delete Tab Backups> ",
 "<M>Every time a Teb file is modified and Saved the original is saved to a file in the Temp folder with an incrementing number as an extension. This function clears them out of the Temp folder.",
 "<V 10>",
####
 "<T MH><S Help>",
 "<V 3>",
 "<T Mhh><s  Help> ",
 "<M>That's how you got here!",
 "<T Mha><s  About> ",
 "<M>Shows the current Version number.",
 "<V 10>",

#####################

 "<T PD><H PDF Page Display\n>",
 "<V 10>",
 "<E><T PO> <s Overview> ",
 "<M>This area shows a representation of what the final PDF will look like (approximately). Down the left side of the page are Bar numbers for the first Bar in the adjacent Stave.",
 "<V1>",
 "<M>You select a Bar by left-clicking on it or a shortcut to edit a Bar is to right-click on it. To select a range of Bars, left-click on the first one and then shift-left-click on the second. It is valid to do both on the same Bar ie. selecting a range of one Bar.",
 "<V1>",
 "<M>The only parts of this page which are directly modifiable are the Lyric lines (assuming you've selected to show any). Each line is an individual entity - even when you've selected more than one Lyric line per stave. You can move between lines with the Up and Down arrow keys but moving along a line to the end will <I not> move down to the next line.",
 "<V1>",
 "<M>This does make moving whole lines around awkward - see <O PE:K:Edit Lyrics> below.",
 "<V1>",
 "<M>Above the page display are 3 buttons:",
 "<V 5>",
 "<E><T PP> <P  {{{ Prev Page > ",
 "<M>Moves to the previous page.",
 "<V 5>",
 "<E><T PE> <P  Edit Lyrics > ",
 "<M>This button pops up an edit window populated with all the Lyric lines. To try and make it easier to match lines with staves the backgound colour is alternately white and grey. Although you can make changes and hit the <R Update> button to see what the changes look like, pressing the <R Cancel> button will undo any changes and revert the page Lyrics to the way they were originally.",
 "<V 5>",
 "<E><T PN> <P  Next Page }}} > ",
 "<M>Moves to the next page.\n",

#####################

 "<T EO><H Page Editing & Options\n>",
 "<V 10><E>",

 "<E><T SL> <S Select> ",
 "<V 5><E>",
 "<T So><s  Collection > ",
 "<T Sm><s  Media > ",
 "<M>These two buttons let you select which Collection to use and with which Media.\n",

 "<E><T TFN> <S File Options> ",
 "<E><T TFN><s  Tab File Name>",
 "<V 5><E>",
 "<T PFN><s  PDF File Name>",
 "<V 5><E>",
 "<T TI><s  Title> ",
 "<M>The <R Tab File Name>, <R PDF File Name> and <R Title> are inter-related in that, by default, the <R PDF File Name> is taken from the <R Tab File Name> with a <s .pdf> extension or visa versa, depending on which comes first. The <R Title> is the same text but without an extension. The only immutable item is the <R Tab File Name>, both the other entries can be changed to your own preference.",
 "<V 5><E>",
 "<T HN><s  Heading Note> ",
 "<M>This gets placed at the top right of the page.\n",

 "<E><T EE> <S Edit> ",
 "<V 5><E>",
 "<T Ee> <P  Edit Bar > ",
 "<M>Click this after selecting a bar to transfer it to the Bar Editor.",
 "<V 5><E>",
 "<T Ec> <P  Clone Bar(s) > ",
 "<M>After selecting one or more bars this will copy the selection to the end of the current bars.",
 "<V 5><E>",
 "<T Sc> <P  Clear Selection > ",
 "<M>Any Bar Selection is cleared.",
 "<V 5><E>",
 "<T Sb> <P  Clear Bar(s) > ",
 "<M>All the Selected Bars will be cleared of all Notes, Headings, Voltas, etc. Any Lyrics below the Bars will not be affected.",
 "<V 5><E>",
 "<T Sd> <P  Delete Bar(s) > ",
 "<M>After a confirmation prompt, all the Selected Bars will be deleted and the resulting empty space removed.\n",

 "<E><T CP> <S Copy/Paste> ",
 "<V 5><E>",
 "<T Ch> <P  Copy > ",
 "<M>Copies whatever elements of the Bars are selected to the right of the button.",
 "<V 5><E>",
 "<T Cb> <P  Before > ",
 "<M>Will insert any Bars in the Copy Buffer <B Before> the selected Bar.",
 "<V 5><E>",
 "<T Co> <P  Over > ",
 "<M>Any Bars in the Copy Buffer (just their previously selected elements) will overwrite any page Bars starting at the selected Bar. If <B Replace> is not selected then the Copy Buffer Bar elements will be added to the existing Bars.",
 "<V 5><E>",
 "<T Cf> <P  After > ",
 "<M>Will insert any Bars in the Copy Buffer <B After> the selected Bar.\n",

 "<E><T BG> <S Background> ",
 "<V 5><E>",
 "<T Bs><P  Set > ",
 "<M>Pops up the Colour Editor to define a Background colour. All Selected Bars will have the defined colour applied as their Background.",
 "<V 5><E>",
 "<T Bc><P  Clear > ",
 "<M>All Selected Bars will have their colour set to the default page Background colour.\n",

 "<E><T LY> <S Lyric> ",
 "<V 5><E>",
 "<T Lu><P  Shift Up One Line > ",
 "<M>Moves all the Lyrics Up one Lyric line. The Lyric line at the top of first page will be placed at the end of the last page.",
 "<V 5><E>",
 "<T Ld><P  Shift Down One Line > ",
 "<M>Moves all the Lyrics Down one Lyric line. The Lyric line at the bottom of the last page will be placed at the start of the first page.\n\n",

 "<E><T TR> <S Transpose> ",
 "<V 5><E>",
 "<T Ts><s  Semi-tones > ",
 "<M>Select how many semitones you want to shift the Selection and press the <P  Go > button. If you Select one Bar then every Note up to the end will be transposed. If you Select a range of Bars then only Notes in those Selected will be transposed. If no Bars are Selected then <I ALL> Notes will be transposed",
 "<V 5><E>",
 "<T To><s  One String > ",
 "<M>With the selection criteria as above the Selected Bars will have their Notes shifted Up or Down one string.",
 "<V 5><E>",
 "<X scheckbox><T Ta><s  Adjust Stings> ",
 "<M>With this item checked, any Note that would move below the nut is adjusted to the next lower string unless it was already on the lowest string in which case the Note will be shifted up one octave. If this is unchecked then the Notes will be shown in <R RED>.\n",

 "<E><T MA> <S Margins> ",
 "<V 5>",
 "<M>These 4 spinboxes let you define the Left, Right, Top and Bottom Margins. These apply to the Tab area only.\n",
]);

  if (OS eq "win32") {
    $win->add(
      [
       "<E><T TP> <S Tab Player> ",
       "<V 5>",
       "<M>Use the slider to set the tempo of the piece (beats/minute). If no start or stop bars are selected then the whole piece will be played. If just the start is selected then play will continue to the end of the piece. If both are selected then the (inclusive) bars will be played. The same applies to the 'Loop' function. If you 'Pause' play, you can continue with either the <R Play> or the <R Loop> button and play will continue in that mode.\n"
      ]);
  }

  $win->add(
[
#####################
 "\n<E><T CE><H Colour Editor (Backgrounds and Fonts)\n>",
 "<V 10>",
 "<M>The Colour Editor works in one of three ways - ForeGround only, BackGround only or ForeGround & Background mode. Which mode depends on where you come from and what you are changing. In all modes you can change both Fore & Back-ground colours so that you can see what the effects are on either choice.",
 "<V2>",
 "In the editor you get 3 sliders that go from 0 to 255 for each primary colour where 0 is no colour and 255 is lots. The resulting mix is shown in a box on the right of the window. This box can have both the background and foreground colours changed but what will be used depends on what mode the editor is in (see the heading top right).",
 "<V2>",
 "Below the sliders is an entry area where you can modify the Hex values for a given colour. If a colour matches one of those listed on the left, that name will appear in this entry box.",
 "<V2>",
 "Below this are six buttons which give you quick access to the current (Chordy) Verse, Chorus, Bridge, Tab, Highlight and Comment colours.",
 "<V2>",
 "The \"My Colours\" box gives you the ability to mix and save 16 different colours you might want to use on a regular basis. Clicking on one of the 16 buttons will set that Fore/Back-ground colour. If you then change the colour with the sliders, you can change the selected colour swatch with the <R Set Colour> button. These colours are only saved if you hit the <R OK> button.",
 "<V2>",
 "Given that you have defined a colour, the <R Lighten> and <R Darken> buttons will adjust the sliders approximately 3% in the appropraite direction.\n",

#####################

 "<E><T BE><H Bar Edit Window\n>",
 "<V 10>",
 "<T Bo><M>This is where all the real work happens and shows two Bars - the one on the left can be edited, the one on the right is really just there so that you can easily see what is coming next. The horizontal lines represent instrument strings - the lowest note string is at the bottom. The vertical lines (not either end of the stave) are the major beats in each bar - crotchets. The subdivisions then represent quavers, semiquavers and demisemiquavers.",
 "<V2>",
 "Frets/Rests are selected and placed by clicking on one of the horizontal/vertical intersections. They can then be deleted by right clicking on them or selected for moving by left clicking on them. If a Fret/Rest is selected it will turn <R red> and can then be moved to a new position by left clicking on the new position.\n",

 "<T Be><S Edit Buttons>",
 "<V 10>",
 "These buttons affect what happens in or to the Edit Stave\n",
 "<P  }}} Cancel {{{ > ",
 "<M>Any items in the Edit area and any selections in the PDF page are removed.",
 "<V 5>",
 "<P  Clear Bar > ",
 "<M>Clears any items in the Edit area.",
 "<V 5>",
 "<P  Set Background > ",
 "<M>Allows you to define a background colour for this single Bar.",
 "<V5>",
 "<P  Clear Background > ",
 "<M>Clears any background colour from the Bar.",
 "<V 5>",
 "<P  Insert Before > ",
 "<M>If you have selected a Bar from the PDF page, the current Bar will be saved and inserted <s before> the selected Bar.",
 "<V 5>",
 "<P  Insert After > ",
 "<M>Same as above except the Bar will be inserted <s after> the selected Bar.",
 "<V 5>",
 "<P  Update > ",
 "<M>Updates the Bar on the PDF page but remains in the Editor.",
 "<V 5>",
 "<P  Save > ",
 "<M>If a PDF page Bar has been selected for editing it will be replaced otherwise the edited Bar will be tacked onto the end of any existing Bars.\n",

 "<T Bf><S Fret Number/Rest>",
 "<V 5>",
 "Clicking on any one will select it for insertion into the Edit Stave.\n",

 "<T Bs><S Slide - Hammer>",
 "<V 5>",
 "Where 2 Fret Numbers appear adjacent on <s ONE> string - click on the <R Slide> or <R Hammer> button and then click on the first (or left most) of the 2 Fret Numbers.\n",

 "<T Bb><S Bend - Bend/Release>",
 "<V 5>",
 "These 2 are slightly different. For just a Bend, click on the <R Bend> button and then click on the Fret Number you want bent. For Bend/Release click on the <R Bend/Release> button and then click on the Fret Number then click on the horizontal/vertical intersection where you want the Release to end.\n",

 "<T Bp><S Bar Options>",
 "<V 5>",
 "These are mainly to handle stuff other than Fret Numbers and Rests.",
 "Place any text you want above the staff in the <R Header Text> box. This can be <R Left> or <R Right> justified and can have <R Volta brackets> included by selecting the appropriate button option.",
 "The <R Repeat> options place a start or end Repeat sign into the Bar.",
 "The <R Note Font> option lets you reduce the size of the font - useful where frets are played very close together and would otherwise overlap. One of the issues here is that PDF fonts can be horizontally compressed but displayed fonts can't. To try and compensate for this, any fret number of 10 and above is rendered on the display in a smaller font - View the PDF to see the difference.",
 "The <R Bar Starts New Line/Page> option does just that - it forces the Bar onto a new line or page.",
 "The <R Note Shift> section works in the same way as the main page <O TR:K:Transpose> section does.",
 "Finally, you can navigate to the Previous or Next Bar via the 4 buttons at the lower right of the window. The <P  Prev Bar > and <P  Next Bar > buttons will prompt to save any changes (if there are any) whereas the two <P  w/Save > buttons will, fairly obviously, save any changes before bringing in the appropriate Bar.\n",
    ]);

  $win->show();
}

1;
