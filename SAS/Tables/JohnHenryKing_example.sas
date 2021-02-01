* formats ;
proc format;
	value trt 1='Placebo' 2='Active' 3='Total';
	value $sex 'F'='Female' 'M'='Male';
	value race 1='White' 2='Black' 3='Hispanic' 4='Other';
	value age low-10='10 and under' 11-12='Pre-teen' 13-high='Teen';
run;

* setting formats and labels;
data ADSL;    
set sashelp.class;    
trt  = rantbl(12345,.5);    
race = rantbl(12345,.5,.4);    
ageg = age;    
bmi  = (weight*703) / height**2;    
attrib age     format=F3.0    label='Age (years)';    
attrib height  format=F7.1    label='Height (inches)';    
attrib weight  format=F7.1    label='Weight (lbs.)';    
attrib sex     format=$sex.   label='Gender';    
attrib race    format=race.   label='Ethnic Origin';    
attrib ageg    format=age.    label='Age group';    
attrib bmi     format=F7.2    label='BMI (kg/m**2)';    
attrib trt     format=trt.    label='Treatment'; 
run;

* adding a total and a character variable;
data adslT;    
set adsl;    
attrib ctrt length=$1 label='Character Treatment';    
do trt=trt,3;       
ctrt = substr('ABC',trt,1);       
output;       
end;
run;


%let data = adslT; 
%let trt  = trt; 
%let cvars = bmi age-numeric-weight ; 
%let dvars = sex race ageg; 
%let avars = sex race age ageg _page_ bmi height weight;  
%let rowofn = yes; 

proc summary data=&data nway completetypes;    
class &trt / preloadfmt;    
output out=BigN(drop=_type_ rename=(_freq_=bigN) index=(&trt)) / levels; 
run; 

data _null_;    
if 0 then set bign(keep=&trt) nobs=nobs;    
length path $256;    
if getoption('DMS') eq 'DMS'       then path = sysget('SAS_EXECFILEPATH');       
else path = getoption('SYSIN');    
path = substr(path,1,find(path,'.',-vlength(path)));    
length rowofn $4;    
if symexist('ROWOFN') then rowofn = upcase(symget('ROWOFN'));   
if substrN(rowofn,1,1) in('1' 'Y' 'O')        then rowofn = "'01'";       else rowofn = ' ';    
call symputX('PATH',path,'G');    call symputX('ROWOFN',rowofn,'G');    
call symputX('TRTLabel',vlabel(&trt),'G');    
call symputX('TRTPercent',int(60/nobs),'G');    
call symputX('COL0',nobs,'G');    
call execute('%put NOTE: Macro variables created:;');    
call execute('%put NOTE- PATH=%nrbquote(&path);');    
call execute('%put NOTE- ROWOFN=%nrbquote(&rowofn);');    
call execute('%PUT NOTE- TRTLabel=&TRTLABEL;');    
call execute('%PUT NOTE- TRTPercent=&TRTpercent;');    
call execute('%PUT NOTE- COL0=&col0;');    
stop; 
run;

proc transpose data=&data(obs=0) out=dvars;    
var &dvars; 
run; 

proc sql noprint;
	select _name_ into: dvars separated by ' ' from dvars;
	quit;
	run;
	%put NOTE: DVARS=&dvars;

proc summary data=&data completetypes chartype missing;    
class &dvars &trt / preloadfmt;    
types (&dvars)*&trt;    
output out=discrete(rename=(_type_=dtype));
run;

ods listing close; 
proc freq data=discrete;    by dtype;    
tables (&dvars)*&trt / norow nopercent;    
weight _freq_ / zeros;    
ods output CrossTabFreqs=CrossTabFreqs(where=(_type_ in(&rowofn '11'))); 
run; 
ods listing;


data CrossTabFreqs(keep=vname rowlabel cell _level_ idlabel _type_);    
length vname $32 rowlabel $64 cell $32 idlabel $64;    
set CrossTabFreqs;    
vname    = vnamex(scan(table,2,' '));    
if _type_ eq '01'        
	then rowlabel = 'n';       
	else rowlabel = vvalueX(vname);    
if colPercent gt 0      
	then cell = catx(' ',Frequency,cats('(',vvalue(colPercent),')'));       
	else cell = cats(Frequency);    
format colPercent 8.1;    
set bign key=&trt/unique;    
idlabel = catx('~',vvalue(&trt),cats('(N=',bign,')')); 
run;

proc transpose data=CrossTabFreqs out=Discrete(drop=_name_) prefix=Col_;    
by vname rowlabel _type_ notsorted;    
var cell;    
id _level_;    
idlabel idlabel; 
run;

data Discrete;    
set Discrete;    
by vname notsorted;    
if first.vname then roworder = 0;    roworder + 1;    
if _type_ eq '01' then roworder = 0;    
drop _type_; 
run;

********** continuous variable ****************;
proc transpose data=&data(obs=0) out=cvars;    
var &cvars; run; 

proc sql noprint;    
select _name_  into :cvars separated by ' ' from cvars; 
quit; 
run; 
%put NOTE: CVARS=&cvars; 

data cvars;    
set cvars end=eof;    
vformatN = vformatNX(_name_);    
vformatD = vformatdX(_name_);    
vformatW = vformatWX(_name_);    
length fmt0 fmt1 $32.;    
fmt0     = cats(vformatN,max(12,vformatW+2),'.',vformatD);    
fmt1     = cats(vformatN,max(12,vformatW+2),'.',vformatD+1);    
return;    
set &data(keep=&cvars);
   drop &cvars;
run; 

%let FMT0 =;  
%let FMT1 =;  
proc sql noprint;    
select        
	catx(' ',_name_, fmt0),        
	catx(' ',_name_, fmt1)        
	into
		:fmt0 separated by ' ',           
		:fmt1 separated by ' '        
	from cvars; 
quit; 
run;
%put NOTE: FMT0=&fmt0; 
%put NOTE: FMT1=&fmt1; 

proc summary data=&data nway completetypes;    
class &trt / preloadfmt;    
var &cvars;   
output out=stats (drop=_type_);    
output out=median(drop=_type_) median=; 
run; 

data stats;    
set stats median(in=in2);    
by &trt;    
if in2 then _STAT_ = 'MEDIAN';    
retain dummy '12345678'; 
run;

proc transpose data=stats out=stat1;    
by &trt _stat_ notsorted;    
where _stat_ eq 'N'; 
var &cvars dummy;   
format &cvars 12.; run; 

proc transpose data=stats out=stat2;    
by &trt _stat_ notsorted;    
where _stat_ in('MIN','MAX');    
var &cvars dummy;    
format &fmt0; run; 

proc transpose data=stats out=stat3;    
by &trt _stat_ notsorted;    
where _stat_ in('MEAN','STD','MEDIAN');    
var &cvars dummy;    
format &fmt1; run; 

proc format;    
invalue statord(upcase just) 'N'=1 'MEAN'=2 'STD'=3  'MEDIAN'=4  'MIN'=5 'MAX'=6;    
invalue statgrp(upcase just) 'N'=1 'MEAN','STD'=2  'MEDIAN'=3  'MIN','MAX'=4;    
value   statgrp               1='N' 2='Mean (SD)'  3='Median'  4='Min, Max'; 
run; 

data stats;    
length vname $32;    
set stat1 stat2 stat3;    
where upcase(_name_) ne 'DUMMY';    
attrib roworder length=8 label='Order';    
attrib order    length=8;    
Vname    = _name_;    
roworder = input(_stat_,statgrp.);    
order    = input(_stat_,statord.);    
col1     = left(col1);    
drop _NAME_ _LABEL_; run; 

proc sort data=stats;    
by vname &trt roworder order _stat_; run;

proc transpose data=stats out=stats(drop=_name_);    
by vname &trt roworder;    
var col1; 
run;


data stats;    
set stats;    
length cell $32 idlabel $256;    
select(roworder);       
	when(2)     cell = catx(' ',col1,cats('(',col2,')')); /* mean(std)*/ 
	when(4)     cell = catx(', ',col1,col2);              /* min, max */       
	otherwise   cell = col1;       
	end;    
attrib rowlabel length=$64 label='Statistic';    
rowlabel = put(roworder,statgrp.);    
set bign key=&trt/unique;    
idlabel = catx('~',vvalue(&trt),cats('(N=',bign,')')); 
run;

proc sort data=stats;    
	by vname roworder rowlabel _level_; run; 

proc transpose data=stats out=Continuous(drop=_name_) prefix=col_;    
by vname roworder rowlabel;    	
var cell;    
id _level_;    
idlabel idlabel; 
run; 

**** final data preparation steps ****;
data avarsV / view=avarsV;    
	stop;    	
	set &data;    
	retain _PAGE_ 0; 
	run; 

proc transpose name=vname label=vlabel data=avarsV out=avars;    
var _PAGE_ &avars %sysfunc(ifC(%superQ(avars) eq,%nrstr(_all_),%nrstr())); run;

data avars(index=(vname));   
set avars;    
if vname eq '_PAGE_' then do;      
	page + 1;       
	delete;      
	end;    
	vorder + 1; 
run;

* rowlabel aanpassen;
data display;    
	attrib page       length=8 label='Break variable used in PROC REPORT BREAK statement';    
	attrib vorder     length=8           label='Order variable used to order the  
												analysis variables, defined in PROC REPORT as ORDER NOPRINT.';    
	attrib vname      length=$32  label='Analysis variable name';    
	attrib vlabel     length=$256          label='Analysis variable label, defined in PROC REPORT
												  as ORDER NOPRINT, displayed with LINE statement in COMPUTE block';  
	attrib roworder   length=8          label='Order variable for row labels, defined in PROC REPORT
											   as ORDER NOPRINT';    
	attrib rowlabel   length=$256          label='Detail row label, derived from categories or statistic labels';   
set Continuous(in=in1) Discrete(in=in2);    
set avars key=vname/unique;    
if in2 then vlabel = catx(', ',vlabel,'n(%)'); 
run;

*** ods rtf set up ***;
* Portrait naar Landscape;
options  
	Orientation =  Portrait
	leftmargin	= 1.5in
	rightmargin	= 1 in
	topmargin	= 1 in
	bottommargin= 1 in 
	Date        =  0   
	Number      =  0   
	Center      =  1   ; 

ods path temp(update) sashelp.tmplmst(read); 
proc template;    define style statsinrows;       
	parent=Styles.Journal;          
	style body from document / leftmargin=1.5in rightmargin=1in topmargin=1in bottommargin   =1in; 
	end; 
run; 

ods listing close; 
ods ESCAPECHAR = '!'; * e.g. for use in title1 ...'Page !{pageof}'; 
ods rtf file="&path.rtf" style=statsinrows;

** titles and footnotes **;
title1 j=Left   h=10pt 'ABC Pharmaceutical' j=r 'Page !{pageof}'; 
title2 j=left   h=10pt 'Protocol: ABC2010-103, A Phase III Study'; 
title3 j=center h=14pt 'Table 14-2.1'; 
title4 j=center h=14pt 'Summary of Demographic Characteristics at Baseline'; 
footnote1 j=left h=8pt "&path.sas" j=right "%sysfunc(datetime(),datetime)";


/* extra kolom; * col_4; 
data display; set display;
label col_4="p-value"; 
if roworder=1 then col_4="0.05";else col_4="   ";
run;
*/

* print;
proc report list nowd missing data=display split='~';    
column page vorder vname vlabel roworder rowlabel 
		("!R'\brdrb\brdrs\brdrw1' &TRTLabel" col_1-col_%eval(&col0-1)) col_&col0 ;
define page       / order order=internal noprint ' ';
define vorder     / order order=internal noprint ' ';
define vname      / order order=internal noprint ' ';
define vlabel     / order order=internal noprint ' ';
define roworder   / order order=internal noprint ' ';
define rowlabel   / display ' '        
	style(column)=          
			[just=left cellwidth=39% protectspecialchars=off pretext="\li240 "];
define col_:      / display style(column)=[just=center cellwidth=&trtPercent.%];    
break before page / page;
compute before page;       f = 0; 
endcomp;    
compute before vlabel / style=[font=(Arial,10pt,bold) just=left];       blankline = ' ';
if f eq 0 then do;
	l1 = 0;         
	f  = 1;         
	end;       
	else l1 = 1;       
	l2 = length(vlabel);       
	line blankline $varying10.-l l1;       
	line vlabel $varying200.-l l2;       
	endcomp; 
run; 

ods rtf close; ods listing;

