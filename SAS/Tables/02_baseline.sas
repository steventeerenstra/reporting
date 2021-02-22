* aparte rijen toevoegen in ds display om de subheadings in orde te krijgen?;


*** read data;
libname data "..\data";* analysis folder;
* get formats;
options fmtsearch= (data.formats);




* A vs B format;
* value labels for formatting order;
proc format;
	value trtf 1='A ' 2='B ' -2='screened' -1='randomized' ;
	value genderf 0='female' 1='male';
	value ynf 0='no' 1='yes';
run;

*get data;
data base; set data.base;
format trt trtf.;
format v1_gender genderf.;
format his_vaat rf_hta.;* lacking format, same as for hypertension;
run;


/* patients for analysis are subset of those randomized, which are subset of those screened
proc freq data=base; table disp_screened*disp_randomized;run;
proc freq data=base; table disp_randomized*disp_analysis;run;
* number of patients in analysis in each group;
proc freq data=base; where disp_analysis=1; table trt;run;
*/

* add all screened, all randomized, diltiazem/placebo with 2 measurements;
data screened; set base; if disp_screened=1;trt=-2; format trt trtf.; run;
data randomized; set base; if disp_randomized=1; trt=-1;format trt trtf.;run;
data analysis; set base; if disp_analysis=1 and trt in (1,2);format trt trtf.;run;

* data baseline table;
data baseline_totals; set screened randomized analysis;run;

%let data_id=analysis; * data where each id has only one record and for which comparison is useful;
%let data = baseline_totals; * augmented data where extra records are added for screened randomized;
%let trt  = trt; 
%let cvars = v1_age 
			v101_lab_hemoglobin
            v101_lab_creatinine v101_lab_asat v101_lab_alat v101_lab_ck
			v101_lab_tropt v101_lab_bnp
			v1_ap_duration ; 
%let dvars = v1_gender v1_race
			 rf_Ht rf_hchol rf_dm rf_fam rf_smoke his_migr his_preg 
			 his_mi his_pci his_vaat 
			v1_ap_ccs v1_ap_type v1_ap_radia v1_ap_nitro 
                v1_ap_1 v1_ap_2 v1_ap_3 v1_ap_4 v1_ap_5;  
%let avars = v1_age v1_gender v1_race 
			 rf_Ht rf_hchol rf_dm rf_fam rf_smoke his_migr his_preg 
			 his_mi his_pci his_vaat 
			v101_lab_hemoglobin v101_lab_creatinine v101_lab_asat v101_lab_alat v101_lab_ck
				v101_lab_tropt v101_lab_bnp
			v1_ap_duration 
			v1_ap_ccs v1_ap_type v1_ap_radia v1_ap_nitro 
                v1_ap_1 v1_ap_2 v1_ap_3 v1_ap_4 v1_ap_5;  
%let rowofn = yes; 
%let col_pvalue=5;
%let p= ;* =p for p-values, = for only descriptives; 



**** totals in the colums for the column headings;
proc summary data=&data nway completetypes;    
class &trt / preloadfmt;    
output out=BigN(drop=_type_ rename=(_freq_=bigN) index=(&trt)) / levels; 
run; 

* TRTpercent: percent space for the treatment columns: smaller gives more columns on one page;
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
call symputX('TRTPercent',int(40/nobs),'G');    
call symputX('COL0',nobs,'G');    
call execute('%put NOTE: Macro variables created:;');    
call execute('%put NOTE- PATH=%nrbquote(&path);');    
call execute('%put NOTE- ROWOFN=%nrbquote(&rowofn);');    
call execute('%PUT NOTE- TRTLabel=&TRTLABEL;');    
call execute('%PUT NOTE- TRTPercent=&TRTpercent;');    
call execute('%PUT NOTE- COL0=&col0;');    
stop; 
run;

**** discrete variables: descriptives ****;
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
tables (&dvars)*&trt / norow nopercent chisq;    
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



*** discrete variables: p-values ****;
ods output fishersexact=fishersexact;
proc freq data=&data_id; table (&dvars)*&trt /fisher;run;
ods output close;
data fishersexact(keep=vname roworder col_&col_pvalue); set fishersexact; 
length vname $32; *same length as in ds discrete;
if label1="Two-sided Pr <= P" or label1="Pr <= P";*2x2 tabel or higher dimensional table;
vname=strip(  scan(Table,2,'') );*get variable name;
col_&col_pvalue=cats(cValue1," !{super F}");
roworder=2;* Fisher's exact test in the second row order;
run; 

ods output chisq=chisq;
proc freq data=&data_id; table (&dvars)*&trt /chisq;run;
ods output close;
data chisq(keep=vname roworder col_&col_pvalue);set chisq;
length vname $32; *same length as in ds discrete;
if statistic="Chi-Square";
vname=strip(  scan(Table,2,'') );*get variable name;
* use the put function to get a character from numeric p-value;
col_&col_pvalue=cats( put(Prob,pvalue6.4) ," !{super C}");
roworder=1; *chi-square test in the first row order;
run;

/* ods escapechar = "!"; proc print data=chisq;run;*/


proc sort data=discrete; by vname roworder;
proc sort data=chisq; by vname roworder;
proc sort data=fishersexact; by vname roworder;
data discretep; merge discrete chisq fishersexact ; by vname roworder;
label col_&col_pvalue="p-value!{super *}";run;


********** continuous variables: descriptives ****************;
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
** all formats have to be same combining stat1 stat2 stat3 furtheron;
** so set them all to a decent maximum, e.g. 21; 
fmt0     = cats(vformatN,max(21,vformatW+2),'.',vformatD);    
fmt1     = cats(vformatN,max(21,vformatW+2),'.',vformatD+1);    
fmt_n    = cats(max(21,vformatW+2),'.');   
return;    
set &data(keep=&cvars);
   drop &cvars;
run; 

%let FMT0 =;  
%let FMT1 =;  
%let FMT_N=;
proc sql noprint;    
select        
	catx(' ',_name_, fmt0),        
	catx(' ',_name_, fmt1), 
	catx(' ',_name_, fmt_n)   
	into
		:fmt0 separated by ' ',           
		:fmt1 separated by ' ',
		:fmt_n separated by ' ' 
	from cvars; 
quit; 
run;
%put NOTE: FMT0=&fmt0; 
%put NOTE: FMT1=&fmt1; 
%put NOTE: FMT_N=&fmt_n;
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
format &cvars &fmt_n; run; *for combining stat1/2/3: all need the same format;

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

/******continuous variables: p-values *****;
ods graphics off;
ods output ttests=ttests;
proc ttest data=&data_id; class &trt; var &cvars; run;
ods output close;
ods graphics on;


data ttests(keep=vname roworder col_&col_pvalue); set ttests; 
if method="Pooled";
vname=variable;
* use the put function to get a character from numeric p-value;
col_&col_pvalue=cats( put(Probt,pvalue6.4) , "!{super T}");*! as escape character;
roworder=1; *t-test in first row;
run;

ods graphics off;
ods output wilcoxontest=wilcoxontest;
proc npar1way data=&data_id wilcoxon; class &trt;var &cvars;run;
ods output close;
ods graphics on;

data wilcoxontest(keep=vname roworder col_&col_pvalue);set wilcoxontest;
if name1="PT2_WIL"; *t approximation to Wilcoxon's test;
vname=variable;
col_&col_pvalue=cats( cValue1 ,"!{super W}");*! as escape character;
roworder=2 ; *wilcoxon test in second row; 
run;

proc sort data=continuous; by vname roworder;
proc sort data=ttests; by vname roworder;
proc sort data=wilcoxontest; by vname roworder;
data continuousp; merge continuous ttests wilcoxontest;by vname roworder;
label col_&col_pvalue="p-value!{super *}";run;*!escape character;
*/


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

* rowlabel aanpassen, was 256;
data display;    
	attrib page       length=8    label='Break variable used in PROC REPORT BREAK statement';    
	attrib vorder     length=8    label='Order variable used to order the  
												analysis variables, defined in PROC REPORT as ORDER NOPRINT.';    
	attrib vname      length=$32  label='Analysis variable name';    
	attrib vlabel     length=$256 label='Analysis variable label, defined in PROC REPORT
												  as ORDER NOPRINT, displayed with LINE statement in COMPUTE block';  
	attrib roworder   length=8    label='Order variable for row labels, defined in PROC REPORT
											   as ORDER NOPRINT';    
	attrib rowlabel   length=$70 label='Detail row label, derived from categories or statistic labels';   
set Continuous&p(in=in1) Discrete&p(in=in2); *&p="_p" gives the inferentials, &p="" not;  
set avars key=vname/unique;    
if in2 then vlabel = catx(', ',vlabel,'n(%)'); 
run; 


*** ods rtf set up ***;
* Portrait naar Landscape;
options  
	Orientation = Portrait
	leftmargin	= 0.5in
	rightmargin	= 0.5in
	topmargin	= 0.5in
	bottommargin= 0.5in 
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
ods ESCAPECHAR = '!'; * e.g. for use in title1 ...'Page !{pageof}' and the super scripts; 
ods rtf file="02_baseline.rtf" style=statsinrows;

** titles and footnotes **;
title1 j=Left   h=10pt 'EDIT-CMD study' j=r 'Page !{pageof}'; 
title2 j=left   h=10pt 'DMC meeting February 2021'; 
title3 j=center h=14pt 'Baseline data'; 
*title4 j=center h=14pt 'Summary of Demographic Characteristics at Baseline';
footnote1 "!{super *} C=Chi-square test, F=Fisher's Exact test, T=t-test, W=Wilcoxon's test"; 
footnote2 j=left h=8pt "&path.sas" j=right "%sysfunc(datetime(),datetime)";


* print;
proc report list nowd missing data=display split='~';   
* if omitted, we get n (sample size) as extra row for categorical variables;
where roworder > 0; 
column page vorder vname vlabel roworder rowlabel col_1 col_2
		("!R'\brdrb\brdrs\brdrw1' &TRTLabel V104 complete" col_3- col_4) ;*col_&col_pvalue;
define page       / order order=internal noprint ' ';
define vorder     / order order=internal noprint ' ';
define vname      / order order=internal noprint ' ';
define vlabel     / order order=internal noprint ' ';
define roworder   / order order=internal noprint ' ';
define rowlabel   / display ' '        
	style(column)=          
			[just=left cellwidth=25% protectspecialchars=off pretext="\li240 "];
define col_:      / display style(column)=[just=center cellwidth=15%];   
*define col_&col_pvalue /display ' ' noprint;  
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


proc his_vaat
