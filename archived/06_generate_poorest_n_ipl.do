
	
*********************************************************************************************************************************************************************************

** Purpose  : Compute an equivalent IPL in 2017 PPPs that retains 2005, 2015 global poverty rate in 2011 PPPs
** Input 1	: The Stata code below was largely created by R.Andres Castaneda and Christoph Lakner (References: https://github.com/worldbank/povcalnet)
** Input 2  : PPP data set, filename(ppp.dta)
** Input 3	: CPI data set, filename(cpi.dta)
** Input 4	: Jolliffe & Prydz (2016) --> https://link.springer.com/article/10.1007/s10888-016-9327-5
** Input 5  : Jolliffe & Prydz (2016), Appendix 2 of Policy Research Working Paper, No. 7606 --> http://documents.worldbank.org/curated/en/837051468184454513/pdf/WPS7606.pdf
** Date     : May 21, 2020
** Author(s): Samuel Kofi Tetteh Baah & Daniel Mahler 

*********************************************************************************************************************************************************************************
	


clear all
set more off

global UPI=c(username) 

if "$UPI"=="WB537472" {
global dir "C:\Users\wb537472\OneDrive - WBG\Documents\Samuel_ETC_Research\paper\analysis_ext"
}

else {
global dir "C:\Users\\${UPI}\OneDrive - WBG\Documents\Samuel_ETC_Research\paper\analysis_ext"
}

cd "$dir"

*mkdir "${dir}/data/equ_ipl_poverty_query"

*Load data 
use `"${dir}/data/implicit_poverty_lines_final.dta"', clear

keep countryname countrycode year impline*
order countryname countrycode year impline*


*With Uzbekistan
preserve
	sort impline_2017
	gen n_2017 = _n

	keep if impline_2017!=.

	count

	forvalues i = 1/`r(N)'{ 

		egen pl_2017_`i'_ = mean(impline_2017) if n<=`i'
		egen pl_2017_`i' = mean(pl_2017_`i'_)
		drop pl_2017_`i'_ 
		
		}

	reshape long pl_2017_, i(countryname countrycode year) j(poorest_n)

	keep if poorest_n == n_2017
	scatter pl_2017_ n_2017

	replace countryname="" if countryname!="Uzbekistan"
	scatter pl_2017_ n_2017, ytitle("IPL 2017 PPP$, cummulative average") mlabel(countryname) xtitle("Number of countries") xlabel(0(20)140) msymbol(O)  graphregion(color(white))
restore 


*Without Uzbekistan
preserve

	drop if countryname=="Uzbekistan"
	sort impline_2017
	gen n_2017 = _n

	keep if impline_2017!=.

	count

	forvalues i = 1/`r(N)'{ 

		egen pl_2017_`i'_ = mean(impline_2017) if n<=`i'
		egen pl_2017_`i' = mean(pl_2017_`i'_)
		drop pl_2017_`i'_ 
		
		}

	reshape long pl_2017_, i(countryname countrycode year) j(poorest_n)

	keep if poorest_n == n_2017
	scatter pl_2017_ n_2017
	count
	
	scatter pl_2017_ n_2017, ytitle("IPL 2017 PPP$, cummulative average") xtitle("Number of countries") xlabel(0(20)140) msymbol(O)  graphregion(color(white))
restore




*Download HFCE from WDI
preserve
	wbopendata, indicator(NE.CON.PRVT.PP.KD; SP.POP.TOTL) clear long

	rename ne_con_prvt_pp_kd hfce_2017_ppp
	rename sp_pop_totl pop

	
	keep countrycode countryname hfce_2017_ppp pop year
	
	gen hfce_2017_ppp_pc = hfce_2017_ppp/pop
	
	sort countrycode 

	tempfile hfce_2017_ppp_pc
	save `hfce_2017_ppp_pc', replace
restore

merge 1:1 countrycode year using `hfce_2017_ppp_pc'
drop if _merge==2 
drop _merge

replace hfce_2017_ppp_pc = ln(hfce_2017_ppp_pc)

scatter impline_2017 hfce_2017_ppp_pc, mlabel(countrycode)  ///
	|| lowess impline_2017 hfce_2017_ppp_pc, mlabel(countrycode) 
	
sort hfce_2017_ppp_pc

gen poorest_n = _n
reg impline_2017 hfce_2017_ppp_pc if poorest_n <=20

egen ipl20_2017_ = mean(impline_2017) if poorest_n <=20 
egen ipl20_2017_ = mean(impline_2017) if poorest_n <=20 

scatter impline_2017 hfce_2017_ppp_pc if poorest_n <=20, mlabel(countrycode)  ///
	|| lfit impline_2017 hfce_2017_ppp_pc if poorest_n <=20, mlabel(countrycode) 

|| function y = max2, ra(gni_pc_atlas2011) clpat (shortdash) lcolor(black) lcolor(red) range(200 420000) text(2.134446 220000 "+2SD=2.13", placement(north) color(maroon)) ///

