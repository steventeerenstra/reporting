%include "macros.sas";
%include "rtf_setup.sas";


*** data ********************************************************;
*** read data;
libname data "..\data";* analysis folder;
* get formats;
options fmtsearch= (data.formats);
proc format;
	value trtf 1='A (V104 complete)' 2='B (V104 complete)' ;
run;
* get data, select only disp_analysis;
data base; set data.base;
if disp_analysis=1;
format trt trtf.;
label ach_conclusion2="Conclusion on ACH2";* correction of text;
run;


******************************************************************;
** titles and footnotes **;
title1 j=Left   h=10pt 'EDIT-CMD study' j=r 'Page !{pageof}'; 
title2 j=left   h=10pt 'DMC meeting February 2021'; 
title3 j=center h=12pt 'Endpoints: all randomized and V104 completed'; 
data _null_;    
length path $256;    
if getoption('DMS') eq 'DMS'       then path = sysget('SAS_EXECFILEPATH');       
else path = getoption('SYSIN');    
path = substr(path,1,find(path,'.',-vlength(path)));    
call symputX('PATH',path,'G');  
stop; 
run;
footnote1 "median<Q1,Q3>, mean+/-std, [min,max]  !{super *}:C=Chi-square test, F=Fisher's Exact test, T=t-test, W=Wilcoxon's test"; 
footnote2 j=left h=8pt "&path.sas" j=right "%sysfunc(datetime(),datetime)";

ods rtf file="06_endpoints.rtf" style=statsinrows startpage=no;
**** end rtf set up ****;

****************tables **********************************************;

*** 6.1 **;
%odsoff();

%macro det_sim_impr(varlist=, dsin=, dsout=);
*reorder 1=deterioration 0=similar 2=improvement ;
* to -1=deterioration 0=similar 1=improvement;
proc format;
	value trtf 1='A (2 visits)' 2='B (2 visits)' ;
	value conclusionf -1="deterioration" 0="similar" 1="improvement";
run;
data &dsout; set &dsin;
%local i;
%do i=1 %to %sysfunc(countw(&varlist));
   %let var = %scan(&varlist, &i, %str( ));
	if &var=1 then &var=-1;
	else if &var=2 then &var=1;
	format  &var conclusionf.;
%end;
run;
%mend det_sim_impr;
%det_sim_impr(varlist=%str(cfr_conclusion imr_conclusion ach_conclusion2), dsin=base, dsout=eff);

%xtab_onerow(dsin=eff,trt=trt,var=cfr_conclusion,  dsout=cfr_concl,pvalue=y);
%xtab_onerow(dsin=eff,trt=trt,var=imr_conclusion,  dsout=imr_concl,pvalue=y);
%xtab_onerow(dsin=eff,trt=trt,var=ach_conclusion2,  dsout=ach_concl2,pvalue=y);

data table6_1; set cfr_concl imr_concl ach_concl2;
run;

%odson();
ods text="Primary endpoint (no difference between epicardial and microvascular spasm, the cutoff of CFR and IMR are used";
proc report data=table6_1;  
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_3) ("!R'\brdrb\brdrs\brdrw1' B" col_4-col_6) ("p-value" col_7);
define row / display ' ' style(column)=  [just=left cellwidth=15% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=10%];
define col_7 / display ' '; 
run;


** 6.2 **;
%odsoff();

%xtab_onerow(dsin=eff,trt=trt,var=primaryendpoint,  dsout=table6_2,pvalue=y);

%odson();
ods text="primary endpoint";
proc report data=table6_2;  
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_2) ("!R'\brdrb\brdrs\brdrw1' B" col_3-col_4) ("p-value" col_5);
define row / display ' ' style(column)=  [just=left cellwidth=15% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=10%];
define col_5 / display ' '; 
run;

/* check on primary endpoint: proc freq data=base; table primaryendpoint*randomized_group / nopercent norow;run;*/

** 6.3 ***;
%odsoff();
%macro no_micro_epi(varlist=, dsin=, dsout=);
*reorder 1=epicardial 2=micro 0=no spasm  ;
* to -2=epicardial -1=micro 0 =no;
proc format;
	value spasmf -2="epicardial" -1="micro" 0="no";
run;
data &dsout; set &dsin;
%local i;
%do i=1 %to %sysfunc(countw(&varlist));
   %let var = %scan(&varlist, &i, %str( ));
	if &var=1 then &var=-2;
	else if &var=2 then &var=-1;
%end;
format V101_SPASM_conclusion spasmf.; 
format V104_SPASM_conclusion spasmf.;
run;
%mend no_micro_epi;

%no_micro_epi(varlist=%str(v101_SPASM_conclusion v104_SPASM_conclusion), dsin=base,dsout=eff);
%xtab_onerow(dsin=eff,trt=trt,var=v101_SPASM_conclusion,  dsout=v101_spasmconcl, rowlabel=%str(Spasm conclusion at v101),pvalue=y);
%xtab_onerow(dsin=eff,trt=trt,var=v104_SPASM_conclusion,  dsout=v104_spasmconcl, rowlabel=%str(Spasm conclusion at v104),pvalue=y);
/* check with old format: proc freq data=base; table v104_spasm_conclusion*trt;run; 0=no 1= epicardial 2=micro*/
data table6_3; set v101_spasmconcl v104_spasmconcl;run;

%odson();
ods text="Acetylcholine: more details, in which epicardial spasm is considered worse than microvascular spasm";
proc report data=table6_3;  
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_3) ("!R'\brdrb\brdrs\brdrw1' B" col_4-col_6) ("p-value" col_7);
define row / display ' ' style(column)=  [just=left cellwidth=15% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=10%];
define col_7 / display ' '; 
run;


*** 6.4 ***;
%odsoff();
%det_sim_impr(varlist=%str(ach_conclusion),dsin=base, dsout=eff);
%xtab_onerow(dsin=eff,trt=trt,var=ach_conclusion,  dsout=table6_4, rowlabel=%str(ach_conclusion),pvalue=y );
data table6_4;set table6_4;
label col_1="deterioration";label col_4="deterioration";
label col_2="similar";label col_5="similar";
label col_3="improvement"; label col_6="improvement";
run;

%odson();
proc report data=table6_4;  
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_3) ("!R'\brdrb\brdrs\brdrw1' B" col_4-col_6) ("p-value" col_7);
define row / display ' ' style(column)=  [just=left cellwidth=15% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=10%];
define col_7 / display ' '; 
run;


/* difference between the following: proc freq data=base; table ach_conclusion* ach_conclusion2;run; */


*** 6.5 ***;
%odsoff();
proc format; 
value ach_concl_g -1="deterioration" 0="similar/improved" 2="similar/improved";
run;
data eff; set base;
ach_concl_g=ach_conclusion;
if ach_concl_g=1 then ach_concl_g=-1;*recode so that the deterioration has the lowest value;
attrib ach_concl_g format =ach_concl_g.  label="ach conclusion (grouped)";
run;
%xtab_onerow(dsin=eff,trt=trt,var=ach_concl_g,  dsout=table6_5,pvalue=y);

%odson();
proc report data=table6_5;  
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_2) ("!R'\brdrb\brdrs\brdrw1' B" col_3-col_4) ("p-value" col_5);
define row / display ' ' style(column)=  [just=left cellwidth=15% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=10%];
define col_5 / display ' '; 
run;



***** 6_6 ***; 
%odsoff();
data eff; set base;run;

%rowvars_colvars(varlist=%str(V101_cft_ade_tmnrest v104_cft_ade_tmnrest tmn_rest_delta), 
trt=trt, dsout=tmn_rest,dsin=eff,testvar=tmn_rest_delta, rowlabel=%str(resting mean transit time));

%rowvars_colvars(varlist=%str(V101_cft_ade_tmnhyp v104_cft_ade_tmnhyp tmn_hyp_delta), 
trt=trt, dsout=tmn_hyp,dsin=eff,testvar=tmn_hyp_delta,rowlabel=%str(hyperemic mean transit time));

%rowvars_colvars(varlist=%str(V101_cft_ade_cfr v104_cft_ade_cfr cfr_delta), 
trt=trt, dsout=cfr,dsin=eff,testvar=tmn_hyp_delta,rowlabel=%str(CFR));

data table6_6; set tmn_rest tmn_hyp cfr;
label col_1="V101";label col_4="V101";label col_2="V104";label col_5="V104";label col_5="delta(4-1)";label col_6="delta(4-1)";
label col_7="p-value";
run;

%odson();
ods text="CFR: more details about components of CFR and showing the change in IMR as percentage instead of using the cutoff";
proc report data=table6_6; 
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_3) ("!R'\brdrb\brdrs\brdrw1' B" col_4-col_6) ("p-value" col_7);
define row / group display ' ' style(column)=  [just=left cellwidth=15% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=10%];
define col_7 / display ' '; 
run;



**** 6_7 ****;
%odsoff();
data eff; set base;run;
/*proc freq data=eff; table cfr_cutoff_v101;run;*/
%xtab_onerow(dsin=eff,trt=trt,var=cfr_cutoff_v101,  dsout=v101_cfr,pvalue=y, rowlabel=%str(V101));
%xtab_onerow(dsin=eff,trt=trt,var=cfr_cutoff_v104,  dsout=v104_cfr,pvalue=y,rowlabel=%str(V104));
data table6_7; set v101_cfr v104_cfr;run;

%odson();
proc report data=table6_7;  
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_2) ("!R'\brdrb\brdrs\brdrw1' B" col_3-col_4) ("p-value" col_5);
define row / display ' ' style(column)=  [just=left cellwidth=15% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=10%];
define col_5 / display ' '; 
run;

**** 6_8 ****;
%odsoff();
proc format; 
value cfr_concl_g -1="deterioration" 0="similar/improved" 2="similar/improved";
run;
data eff; set base;
cfr_concl_g=cfr_conclusion;
if cfr_concl_g=1 then cfr_concl_g=-1;*recode so that the deterioration has the lowest value;
attrib cfr_concl_g format =cfr_concl_g. label="cfr conclusion based on CFR <=2 (grouped)";
run;
%xtab_onerow(dsin=eff,trt=trt,var=cfr_concl_g,  dsout=table6_8,pvalue=y);

%odson();
proc report data=table6_8;  
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_2) ("!R'\brdrb\brdrs\brdrw1' B" col_3-col_4) ("p-value" col_5);
define row / display ' ' style(column)=  [just=left cellwidth=15% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=10%];
define col_5 / display ' '; 
run;

**** 6.9 ****;
%odsoff();
data eff; set base;
imr_delta=v104_cft_ade_imr - v101_cft_ade_imr;
run;

%rowvars_colvars(varlist=%str(V101_cft_ade_tmnhyp v104_cft_ade_tmnhyp tmn_hyp_delta), 
trt=trt, dsout=tmn_hyp,dsin=eff,testvar=tmn_hyp_delta,rowlabel=%str(hyperemic transit time));

%rowvars_colvars(varlist=%str(V101_cft_ade_Pdhyp v104_cft_ade_Pdhyp Pdhyp_delta), 
trt=trt, dsout=Pdhyp,dsin=eff,testvar=pdhyp_delta,rowlabel=%str(Pd at hyperemia));

%rowvars_colvars(varlist=%str(V101_cft_ade_imr v104_cft_ade_imr imr_delta), 
trt=trt, dsout=imr,dsin=eff,testvar=imr_delta,rowlabel=%str(IMR));

data table6_9; set tmn_hyp pdhyp imr;
label col_1="V101";label col_4="V101";label col_2="V104";label col_5="V104";
label col_3="delta(4-1)"; label col_6="delta(4-1)";
label col_7="p-value";
if row="IMR" then do; col_3="  "; col_6="  ";col_7=" ";end;
run;

%odson();
ods text="IMR: more details on components and showing the change in IMR as as percentage instead of using cutoff";
proc report data=table6_9; 
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_3) ("!R'\brdrb\brdrs\brdrw1' B" col_4-col_6) ("p-value" col_7);
define row / group display ' ' style(column)=  [just=left cellwidth=10% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=12%];
define col_7 / display ' ' style(column)=[just=right cellwidth=8%];; 
run;


*** 6_10 ****;
%odsoff();
/* proc freq data=eff; table imr_cutoff_v101;run; */
%xtab_onerow(dsin=eff,trt=trt,var=imr_cutoff_v101,  dsout=v101_imr,rowlabel=%str(IMR at v101),pvalue=y);
%xtab_onerow(dsin=eff,trt=trt,var=imr_cutoff_v104,  dsout=v104_imr,rowlabel=%str(IMR at v104),pvalue=y);
data table6_10; set v101_imr v104_imr;
label col_1="IMR >= 25 (abnormal)";label col_3="IMR >= 25 (abnormal)";
label col_2="IMR < 25 (normal)";label col_4="IMR < 25 (normal)";
if row="imr_cutoff_v101" then row="IMR at v101";
if row="imr_cutoff_v104" then row="IMR at v104";
run;

%odson();
proc report data=table6_10;  
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_2) ("!R'\brdrb\brdrs\brdrw1' B" col_3-col_4) ("p-value" col_5);
define row / display ' ' style(column)=  [just=left cellwidth=15% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=10%];
define col_5 / display ' '; 
run;


*** 6.11 ****;
%odsoff();

proc format; 
value imr_concl_g -1="deterioration" 0="similar/improved" 2="similar/improved";
run;
data eff; set base;
imr_concl_g=imr_conclusion;
if imr_concl_g=1 then imr_concl_g=-1;*recode so that the deterioration has the lowest value;
attrib imr_concl_g format =imr_concl_g. label="imr conclusion (grouped)";
run;
%xtab_onerow(dsin=eff,trt=trt,var=imr_concl_g,  dsout=table6_11,pvalue=y);

%odson();
proc report data=table6_11;  
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_2) ("!R'\brdrb\brdrs\brdrw1' B" col_3-col_4) ("p-value" col_5);
define row / display ' ' style(column)=  [just=left cellwidth=15% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=10%];
define col_5 / display ' '; 
run;



*** 6.12 ****;
%odsoff();

%macro label(var=,label=, dsout=eff, dsin=base);
data &dsout;set &dsin;
	attrib &var._101 label=&label;
	attrib &var._104 label=&label;
	attrib D_&var    label=&label;
run;
%mend label;

%macro subtable(varlist=);
%local i; *for each variable make the rows in the table;
%do i=1 %to %sysfunc(countw(&varlist));
	%let var=%scan(&varlist,&i,%str( ));
	%put &var;
	%label(var=&var,label="&var"); 
	%rowvars_colvars(varlist=%str(&var._101 &var._104 D_&var), 
		trt=trt, dsout=&var,dsin=eff,testvar=D_&var);
%end;
%mend subtable;

*options mprint mprintnest symbolgen mlogic; 
*options nomprint nomprintnest nosymbolgen nomlogic;
%subtable(varlist=SAQ_A SAQ_B SAQ_C SAQ_D SAQ_E);

data table6_12; set SAQ_A SAQ_B SAQ_C SAQ_D SAQ_E;
label col_1="V101";label col_4="V101";label col_2="V104";label col_5="V104";label col_3="delta(4-1)";label col_6="delta(4-1)";
label col_7="p-value";
run;

%odson();
ods text="Other endpoints: angina and QoL";
proc report data=table6_12; 
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_3) ("!R'\brdrb\brdrs\brdrw1' B" col_4-col_6) ("p-value" col_7);
define row / group display ' ' style(column)=  [just=left cellwidth=8% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=12%];
define col_7 / display ' ' display style(column)=[just=right cellwidth=8%]; 
run;

**** 6_13 *******;
%odsoff();
%subtable(varlist=QoL1 QoL2 QoL3 QoL4 QoL5 QoL6 QoL7 QoL8);
data table6_13; set QoL1 QoL2 QoL3 QoL4 QoL5 QoL6 QoL7 QoL8;
label col_1="V101";label col_4="V101";label col_2="V104";label col_5="V104";label col_3="delta(4-1)";label col_6="delta(4-1)";
label col_7="p-value";
run;

%odson();
proc report data=table6_13; 
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_3) ("!R'\brdrb\brdrs\brdrw1' B" col_4-col_6) ("p-value" col_7);
define row / group display ' ' style(column)=  [just=left cellwidth=8% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=12%];
define col_7 / display ' ' style(column)=[just=right cellwidth=8%];; 
run;


*** 6_14 ****;
%odsoff;
data eff; set base;run;

%rowvars_colvars(varlist=%str(V101_AP_CCS v104_AP_CCS D_AP_CCS), 
trt=trt, dsout=ap_ccs,dsin=eff,testvar=d_AP_CCS,rowlabel=%str(CSS classification));

data ap_css; set ap_ccs;
label col_1="V101";label col_4="V101";label col_2="V104";label col_5="V104";
label col_3="delta(4-1)"; label col_6="delta(4-1)";
label col_7="p-value";
run;

%odson();
proc report data=ap_css; 
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_3) ("!R'\brdrb\brdrs\brdrw1' B" col_4-col_6) ("p-value" col_7);
define row / group display ' ' style(column)=  [just=left cellwidth=15% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=10%];
define col_7 / display ' '; 
run;
 

****6_15***;
%odsoff();
proc format; value ccsf 1="I" 2="II" 3="III" 4="IV";run;
data eff; set base;
format v101_ap_ccs ccsf.; format v104_ap_ccs ccsf.;run;

%xtab_onerow(dsin=eff,trt=trt,var=v101_AP_CCS,  dsout=v101_ap_ccs,rowlabel=%str(CCS at v101),pvalue=y);
%xtab_onerow(dsin=eff,trt=trt,var=v104_AP_CCS,  dsout=v104_ap_ccs,rowlabel=%str(CCS at v104),pvalue=y);
data table6_15; set v101_ap_ccs v104_ap_ccs;
label col_1="I";label col_5="I";
label col_2="II";label col_6="II";
label col_3="III"; label col_7="III";
label col_4="IV";label col_8="IV";
run;

%odson();
proc report data=table6_15;  
column row ("!R'\brdrb\brdrs\brdrw1' A" col_1-col_4) ("!R'\brdrb\brdrs\brdrw1' B" col_5-col_8) ("p-value" col_9);
define row / display ' ' style(column)=  [just=left cellwidth=15% protectspecialchars=off pretext="\li240 "];	
define col_:      / display style(column)=[just=right cellwidth=10%];
define col_9 / display ' '; 
run;


ods rtf close;
ods listing;
