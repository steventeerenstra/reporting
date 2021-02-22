**** table macros ****;

%macro xtab_onerow(var=, trt=, dsout=,dsin=, pvalue=,rowlabel=%str());
** 2 x 2 table, categorical var x treatment, into a single row;
** categories have to be predefined with a format option;
** then preprocess data to include zeros for missing categories;
proc summary data=&dsin completetypes chartype missing;
class &var &trt /preloadfmt;
types &var*&trt;
output out=withEmptyCategories;
run;

** one proc freq data=withEmptyCategories for frequencies;
**       including empty categories;
proc freq data=withEmptyCategories; 
table &var*&trt / norow nopercent;
weight _freq_ / zeros;
ods  output CrossTabFreqs=Crosstabfreqs; 
run;
* now make a one record dataset with group=&trt, 
* columns with frequencies ordered by group and by category value;
* we store the value labels in "collabel" for later column headers;
data CrossTabFreqs1(keep=group col cell collabel); set CrossTabFreqs;
if _type_='11';
group=&trt;
col=&var;
cell=catt(Frequency,' (',put(ColPercent,4.1),'%)');
collabel=vvalue(&var);* store the formatted valuelabels of &var;
run;


** another proc freq data=&dsin for the chi square if requested;
%IF (&pvalue=y or &pvalue=1) %THEN %DO; 
 proc freq data=&dsin; 
 table &var*&trt / norow nopercent chisq;
 ods  output chisq=chisq; 
 run;

 data pvalue(keep=group col  cell collabel); set chisq; 
 if Statistic="Chi-Square";
 group=100000; col=1; * give a large value, so that it ordered as last; 
 cell=put(Prob,pvalue6.4); 
 collabel="P";*for use als column header;
 run; 
%END;


data crosstab; set crosstabfreqs1 
%IF (&pvalue=y or &pvalue=1) %THEN %DO; pvalue %END;;;run;

proc sort data=crosstab; by group col;run;* get the right order of columns;
* add a counter for the frequencies columns and the p-value column;
data crosstab; set crosstab; colnumber =_n_;run;

proc transpose data=crosstab prefix=col_ out=&dsout(drop=_name_);
var cell;
id colnumber; * to number the columns col_1, col_2 etc;
idlabel collabel; *to label the columns with the category labels;
run;

*get the row label from the label of &var;
%IF &rowlabel = %THEN %DO;
data _null_;set &dsin; call symput('rowlabel',vlabel(&var));run;
%END;
* or else it is taken from the macro argument; 

* set the row label;
data &dsout; set &dsout;length row $ 256;;  row="&rowlabel";run;

*clean up;
proc delete data=crosstab crosstabfreqs1 crosstabfreqs withEmptyCategories
%IF (&pvalue=y or &pvalue=1) %THEN %DO; chisq %END;;;run;
%mend xtab_onerow;

%macro rowvars_colvars(varlist=%str(V101_cft_ade_tmnrest v104_cft_ade_tmnrest tmn_rest_delta), trt=trt, 
                        dsout=table,dsin=eff,testvar=tmn_rest_delta, rowlabel=%str());
* loop over the variables in the &var_list and generate descriptive statistics;
%local i;%local var;
%do i=1 %to %sysfunc(countw(&varlist));
   %let var = %scan(&varlist, &i, %str( ));
	proc summary data=&dsin  median Q1 Q3 mean std min max print; 
	class &trt; var &var;
	output out=summary0 median=median Q1=Q1 Q3=Q3 mean=mean std=std min=min max=max;
	run;
    *get the row (i.e. the label) from the label of &var;
	%IF &rowlabel = %THEN %DO;
		data _null_;set &dsin(keep=&var obs=1); call symput('rowlabel',vlabel(&var));run;
	%END;
	* or else it is taken from the macro argument; 

	* make a three records (three statistics) 
	* identified by group=&trt, row=&row (the variable name), subrow (the type of statistc);
    *    and col=&i (the i-th variable),  ;
	data summary1(keep=group row subrow col cell var ); set summary0;
	if _type_ > 0;* to remove summaries over all groups pooled;
	length row $ 256; length cell $ 256;length var $ 256;
	group=&trt;row="&rowlabel";var="&var";col=&i;
		* make three rows of information per variable;
		subrow=1;cell=catt(put(median,5.2),'<',put(Q1,5.2),' , ',put(Q3,5.2),'>');output;
		subrow=2;cell=catt(put(mean,5.2),'+/-',put(std,5.2));output;
		subrow=3;cell=catt('[',put(min,5.2),'-',put(max,5.2),']');output;
	run; 
	proc append base=summary data=summary1 force;quit;
%end;

* if test statistics are required;
%if &testvar ^= %then %do;
	ods graphics off;
	*** wilcoxon test;
	ods output wilcoxontest=wilcoxontest;
	proc npar1way data=&dsin wilcoxon; class &trt;var &testvar;run;
	ods output close;

	data wilcoxontest(keep=group row subrow col cell var);
	length row $ 256; length cell $ 256;length var $ 256;
	set wilcoxontest;
	if name1="PT2_WIL"; *t approximation to Wilcoxons test;
	group=100;*larger than any group value;
	row="&rowlabel"; subrow=1;*aligned with median <Q1,Q3>;
	var="&testvar";col=1;
	cell=cats(cValue1,"!{super W}");*! as escape character;
	run;

	** ttest ***;
	ods output ttests=ttests;
	proc ttest data=&dsin; class &trt; var &testvar; run;
	ods output close;


	data ttests(keep=group row subrow col cell var); 
	length row $ 256; length cell $ 256;length var $ 256;
	set ttests; 
	if method="Pooled";
	group=100; * larger than any group value;
	row="&rowlabel";subrow=2; *aligned with means;
	var="&testvar";col=1;
	* use the put function to get a character from numeric p-value;
	cell=cats( put(Probt,pvalue6.4) , "!{super T}");*! as escape character;
	run;
%end;
*** add;
ods graphics on;
data summary_final; 
set summary 
    %if &testvar ^= %then %do; wilcoxontest ttests;%end;;
run;

** transpose for each subrow separtely;
proc sort data=summary_final; by group col ;run;
%local j;
%do j=1 %to 3;
	proc transpose data=summary_final(where=(subrow=&j)) prefix=col_ out=summaryrow&j(drop=_name_);
	by row;
	var cell;
	run;
%end;
* and combine;
data &dsout; set summaryrow1 summaryrow2 summaryrow3;run;
* clean up;
proc delete data=summary0 summary1 summary summary_final summaryrow1 summaryrow2 summaryrow3 
	%if &testvar ^= %then %do;ttests wilcoxontest;%end;;
run;
%mend rowvars_colvars;

%macro xtab(row=MedDRASOC5, column=adv_eve_sev, dsin=ae_sev, dsout=ae_sev_SOC);
* make a proc report dataset corresponding to proc freq table &row*&column ;  
ods output crosstabfreqs=crosstabfreqs;
proc freq data=&dsin; table &row*&column/norow nocol;run;
ods output close;

data CrossTab(keep=row col cell collabel rowlabel); set CrossTabFreqs;
if _type_='11';
row=&row;
col=&column;
cell=catt(Frequency,' (',put(Percent,4.1),'%)');
collabel=vvalue(&column);* store the formatted valuelabels of &column;
rowlabel=vvalue(&row); * idem for &var;
run;

proc sort data=crosstab; by row col;run;* get the right order of columns;
* add a counter for the frequencies columns and the p-value column;
data crosstab; set crosstab;by row; if first.row then colnumber=0;colnumber+1;run;

proc transpose data=crosstab prefix=col_ out=&dsout(drop=_name_);
by row rowlabel;
var cell;
id colnumber; * to number the columns col_1, col_2 etc;
idlabel collabel; *to label the columns with the category labels;
run;

* note that in proc report the row names come from the variable rowlabel;
proc delete data=crosstabfreqs crosstab;run;
%mend xtab;



** data processing macros ***;
%macro sameformat(varlist=, format=);
%local i; %local var;
%do i=1 %to %sysfunc(countw(&varlist));
	%let var=%scan(&varlist,&i,%str( )); 
	format &var &format;;
%end;
%mend;


*** other **;
%macro ODSOff(); /* Call prior to processing */
ods graphics off;
ods exclude all;
ods noresults;
%mend;
 
%macro ODSOn(); /* Call after processing */
ods graphics on;
ods exclude none;
ods results;
%mend;
