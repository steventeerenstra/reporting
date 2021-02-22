*** ods rtf set up ***;
* Portrait naar Landscape;
options  
	Orientation = Landscape
	leftmargin	= 0.2 in
	rightmargin	= 0.2 in
	topmargin	= 0.5 in
	bottommargin= 0.5 in 
	Date        =  0   
	Number      =  0   
	Center      =  1   ; 


ods path temp(update) sashelp.tmplmst(read); 
proc template;    define style statsinrows;       
	parent=Styles.Journal;          
	style body from document / leftmargin=1.5in rightmargin=1in topmargin=1in bottommargin   =1in; 
	style usertext from usertext / just=c;
end; 
run; 
ods ESCAPECHAR = '!'; 


