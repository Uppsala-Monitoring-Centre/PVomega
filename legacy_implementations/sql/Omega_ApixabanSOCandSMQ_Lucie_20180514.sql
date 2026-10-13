/*****************************************
         Compute Omega values
*****************************************/
-- First, we construct several temporary tables to associate report IDs to either Drugs or Reactions
-- The first table with the reports and substances
-- The second table with the reports and reactions
-- Then, we use the temporary tables mentionned above to count numbers of reports
-- for single drugs
-- for single reactions
-- for drug-drug pairs
-- for drug-reaction pairs
-- Then, we create a table with all necessary counts to compute Omega and Omega025
-- Finally, we create the result table with the Omega values





-- Drug table
-------------------------
IF OBJECT_ID('tempdb..#ReportDrugList') IS NULL --NOT NULL
	--DROP TABLE #ReportDrugList
	BEGIN
	CREATE TABLE #ReportDrugList (
		ReportID INT, 
		Drecno char(6) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		PRIMARY KEY (ReportID,Drecno))
	INSERT INTO #ReportDrugList
	SELECT DISTINCT Report.ReportID, MDI.Drecno
	FROM UMCReport20180102.UMCReport.Report							Report
	JOIN UMCReport20180102.[UMCReport].[Drug]						Drug	ON Drug.ReportID = Report.ReportID
	JOIN UMCReport20180102.[UMCReport].[TB_MappedDrugInformation]	MDI		ON MDI.[MappedReportedDrugID] = Drug.[UMCValidated_MappedReportedDrugID]
	WHERE 
		Report.UMCCalculated_DeleteDate IS NULL AND Report.UMCCalculated_ForeignCase = 0
		AND (Report.UMCCalculated_PreferredICSR_ReportID IS NULL OR Report.UMCCalculated_PreferredICSR_ReportID = Report.ReportID)
		AND Drug.[UMCValidated_DrugCharacterizationID] IN (1, 3)
	END
	-- Takes 1 min to create
	-- 17,508,152 rows

SELECT COUNT(*) FROM #ReportDrugList
SELECT TOP(20) * FROM #ReportDrugList

-- Reaction table
-------------------------
IF OBJECT_ID('tempdb..#ReportReactionList') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #ReportReactionList
	CREATE TABLE #ReportReactionList (ReportID INT, MedDRAPTCode INT, MedDRASOCCode INT, PRIMARY KEY (ReportID,MedDRAPTCode, MedDRASOCCode))
	INSERT INTO #ReportReactionList
	SELECT DISTINCT Report.ReportID, MTI.MedDRAPTCode, MTI.[MedDRAPrimarySOCCode]
	FROM UMCReport20180102.UMCReport.Report							Report
	JOIN UMCReport20180102.[UMCReport].[Reaction]					Reaction	ON Reaction.ReportID = Report.ReportID
	JOIN UMCReport20180102.[UMCReport].[TB_MappedTermInformation]	MTI			ON MTI.[MappedReportedTermID] = Reaction.[UMCValidated_MappedReportedTermID]
	

	WHERE 
		Report.UMCCalculated_DeleteDate IS NULL AND Report.UMCCalculated_ForeignCase = 0
		AND (Report.UMCCalculated_PreferredICSR_ReportID IS NULL OR Report.UMCCalculated_PreferredICSR_ReportID = Report.ReportID)
		
	END
	-- takes 7 minutes to create 
	-- 33,765,533 rows

--SELECT * FROM #ReportReactionList

-- Single drug counts
------------------------------
IF OBJECT_ID('tempdb..#SingleDrugCounts') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #SingleDrugCounts 
	CREATE TABLE #SingleDrugCounts (
		Drecno char(6) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		DrugName varchar(1500), 
		NbReports INT, 
		PRIMARY KEY (Drecno))
	INSERT INTO #SingleDrugCounts
	SELECT #ReportDrugList.Drecno, NULL, COUNT(DISTINCT #ReportDrugList.ReportID)
	FROM #ReportDrugList 
	GROUP BY #ReportDrugList.Drecno

	UPDATE #SingleDrugCounts
	SET 
		DrugName = MP.TRADENAME
	FROM UMCReport20180102.ReferenceDrug.MEDICINALPROD	AS MP	
	JOIN #SingleDrugCounts ON #SingleDrugCounts.Drecno COLLATE SQL_Latin1_General_CP1_CI_AS = MP.[Drecno]
	WHERE 
		MP.DATABASSTATUS = 0 
		AND MP.SEQ1 = '01' 
		AND MP.SEQ2 = '001'
	END



SELECT TOP(10) * FROM #SingleDrugCounts
--SELECT COUNT(*) FROM #SingleDrugCounts

-- ADR counts
------------------------------
IF OBJECT_ID('tempdb..#ReactionCounts') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #ReactionCounts
	CREATE TABLE #ReactionCounts (MedDRAPTCode INT, ReactionName varchar(100), MedDRASOCCode INT, ReactionNameSOC varchar(100), NbReports INT, PRIMARY KEY (MedDRAPTCode, MedDRASOCCode))
	INSERT INTO #ReactionCounts
	SELECT #ReportReactionList.MedDRAPTCode, NULL, #ReportReactionList.MedDRASOCCode, NULL, COUNT(DISTINCT #ReportReactionList.ReportID)
	FROM #ReportReactionList 
	GROUP BY #ReportReactionList.MedDRAPTCode, #ReportReactionList.MedDRASOCCode

	UPDATE #ReactionCounts
	SET 
		ReactionName = MedDRA.PT_NAME,
		ReactionNameSOC = MedDRA.SOC_NAME
	FROM UMCReport20180102.[ReferenceTerm].[MedDRA_MD_Hierarchy] AS MedDRA	
	JOIN #ReactionCounts ON #ReactionCounts.MedDRAPTCode = MedDRA.PT_CODE and #ReactionCounts.MedDRASOCCode = MedDRA.[SOC_CODE]
	
	WHERE MedDRA.PRIMARY_SOC_FG = 'Y'
	
	END

SELECT TOP(10) * FROM #ReactionCounts
--SELECT COUNT(*) FROM #ReactionCounts


-- Drug-Drug counts
------------------------------
IF OBJECT_ID('tempdb..#DrugDrugCounts') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #DrugDrugCounts
	CREATE TABLE #DrugDrugCounts (
		DrecnoD1 char(6) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		DrecnoD2 char(6) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		NbReports INT, 
		PRIMARY KEY (DrecnoD1,DrecnoD2)
	)
	INSERT INTO #DrugDrugCounts
	SELECT D1.Drecno, D2.Drecno, COUNT(DISTINCT D1.ReportID)
	FROM #ReportDrugList D1
	JOIN #ReportDrugList D2 ON D2.ReportID=D1.ReportID
	WHERE D1.Drecno != D2.Drecno
	GROUP BY D1.Drecno, D2.Drecno
	END

SELECT TOP(10) * FROM #DrugDrugCounts
--SELECT COUNT(*) FROM #DrugDrugCounts


-- Drug-ADR counts
------------------------------
IF OBJECT_ID('tempdb..#DrugReactionCounts') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #DrugReactionCounts
	CREATE TABLE #DrugReactionCounts (
		Drecno char(6) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		MedDRAPTCode INT, 
		NbReports INT, 
		PRIMARY KEY (Drecno,MedDRAPTCode)
	)
	INSERT INTO #DrugReactionCounts
	SELECT D.Drecno, R.MedDRAPTCode, COUNT(DISTINCT D.ReportID)
	FROM #ReportDrugList D
	JOIN #ReportReactionList R ON R.ReportID=D.ReportID
	GROUP BY D.Drecno, R.MedDRAPTCode
	END

SELECT TOP(10) * FROM #DrugReactionCounts
--SELECT COUNT(*) FROM #DrugReactionCounts



DECLARE @n___ INT = (
	SELECT COUNT(DISTINCT Report.ReportID)
	FROM UMCReport20180102.UMCReport.Report							Report
	WHERE Report.UMCCalculated_DeleteDate IS NULL AND Report.UMCCalculated_ForeignCase = 0
		AND (Report.UMCCalculated_PreferredICSR_ReportID IS NULL OR Report.UMCCalculated_PreferredICSR_ReportID = Report.ReportID)
)



/************************************
		Big count table
************************************/

DECLARE @Drug1Drecno char(6) = (
	SELECT DISTINCT MDI.Drecno
	FROM UMCReport20180102.[UMCReport].[TB_MappedDrugInformation] MDI
	WHERE MDI.SubstanceName = 'rivaroxaban'
)
SELECT @Drug1Drecno


IF OBJECT_ID('tempdb..#Drug1AllCounts') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #Drug1AllCounts
	CREATE TABLE #Drug1AllCounts (
		Drecno1 varchar(6) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Drug1 varchar(1500) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		Drecno2 varchar(6) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Drug2 varchar(1500) COLLATE SQL_Latin1_General_CP1_CI_AS,
		MedDRASOC INT ,
		MedDRAPT INT,
		SOC varchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Reaction varchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		n___ INT,
		n1__ INT,
		n_1_ INT,
		n__1 INT,
		n11_ INT,
		n1_1 INT,
		n_11 INT,
		Observed INT,
		Expected INT,
		PRIMARY KEY (Drecno1,Drecno2,MedDRAPT, MedDRASOC)
	)
	INSERT INTO #Drug1AllCounts 
	SELECT 
		D1.Drecno COLLATE SQL_Latin1_General_CP1_CI_AS, 
		SingleD1.DrugName COLLATE SQL_Latin1_General_CP1_CI_AS,
		D2.Drecno COLLATE SQL_Latin1_General_CP1_CI_AS, 
		SingleD2.DrugName COLLATE SQL_Latin1_General_CP1_CI_AS,
		ADR.MedDRASOCCode ,
		ADR.MedDRAPTCode , 
		SingleR.ReactionNameSOC ,
		SingleR.ReactionName ,
		@n___,
		SingleD1.NbReports, 
		SingleD2.NbReports,
		SingleR.NbReports,
		DD.NbReports,
		RD1.NbReports,
		RD2.NbReports,
		COUNT(DISTINCT D1.ReportID) as Observed,
		ResearchProjects.dbo.CxxyExpected(@n___, SingleD1.NbReports, SingleD2.NbReports, SingleR.NbReports, DD.NbReports, RD1.NbReports, RD2.NbReports, COUNT(DISTINCT D1.ReportID))
	FROM #ReportDrugList		D1
	JOIN #ReportDrugList		D2			ON D2.ReportID = D1.ReportID
	JOIN #ReportReactionList	ADR			ON ADR.ReportID = D1.ReportID
	JOIN #SingleDrugCounts		SingleD1	ON SingleD1.Drecno = D1.Drecno
	JOIN #SingleDrugCounts		SingleD2	ON SingleD2.Drecno = D2.Drecno
	JOIN #ReactionCounts		SingleR		ON SingleR.MedDRAPTCode = ADR.MedDRAPTCode  and SingleR.MedDRASOCCode = ADR.MedDRASOCCode
	JOIN #DrugDrugCounts		DD			ON DD.DrecnoD1 = D1.Drecno	AND DD.DrecnoD2 = D2.Drecno
	JOIN #DrugReactionCounts	RD1			ON RD1.Drecno = D1.Drecno	AND RD1.MedDRAPTCode = ADR.MedDRAPTCode
	JOIN #DrugReactionCounts	RD2			ON RD2.Drecno = D2.Drecno	AND RD2.MedDRAPTCode = ADR.MedDRAPTCode
	--LEFT JOIN UMCReport.ReferenceTermSMQ.SMQ_LIST li ON ADR.MedDRAPTCode = li.
	WHERE D1.Drecno = @Drug1Drecno
		AND D1.Drecno != D2.Drecno

	GROUP BY 
		D1.Drecno, 
		SingleD1.DrugName,
		D2.Drecno, 
		SingleD2.DrugName,
		ADR.MedDRASOCCode,
		ADR.MedDRAPTCode, 
		SingleR.ReactionNameSOC,
		SingleR.ReactionName,
		SingleD1.NbReports, 
		SingleD2.NbReports,
		SingleR.NbReports,
		DD.NbReports,
		RD1.NbReports,
		RD2.NbReports
	ORDER BY Observed DESC
	END

select top(10) * FROM #Drug1AllCounts


-------------------------------------------------------
-- We need to produce the triplets that have Omega025>0
-- so as to produce the list of reports to be included in the case info file
-------------------------------------------------------
IF OBJECT_ID('tempdb..#KeepIn_ReportList') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #KeepIn_ReportList
	CREATE TABLE #KeepIn_ReportList (
		ReportID INT,
		PRIMARY KEY (ReportID)
	)
	INSERT INTO #KeepIn_ReportList
	SELECT DISTINCT D1.ReportID
	FROM #Drug1AllCounts		DAC
	JOIN #ReportDrugList		D1		ON D1.Drecno = DAC.Drecno1
	JOIN #ReportDrugList		D2		ON D2.Drecno = DAC.Drecno2
	JOIN #ReportReactionList	R		ON R.MedDRAPTCode = DAC.MedDRAPT
	WHERE ResearchProjects.dbo.ICoe025(DAC.Observed, DAC.Expected) > 0
		AND	D1.ReportID = D2.ReportID
		AND D1.ReportID = R.ReportID
	END





-------------------------------------------------------
-- We add the SMQs
-------------------------------------------------------

IF OBJECT_ID('tempdb..#Drug1AllCountsSMQ') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #Drug1AllCountsSMQ
	CREATE TABLE #Drug1AllCountsSMQ (
		Drecno1 varchar(6),
		Drug1 varchar(1500), 
		Drecno2 varchar(6),
		Drug2 varchar(1500),
		MedDRASOC INT,
		MedDRAPT INT,
		SOC varchar(100),
		Reaction varchar(100), 
		SMQCode INT,
		SMQName varchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS,
		SMQScope varchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
		n___ INT,
		n1__ INT,
		n_1_ INT,
		n__1 INT,
		n11_ INT,
		n1_1 INT,
		n_11 INT,
		Observed INT,
		Expected INT,
		PRIMARY KEY (Drecno1,Drecno2,MedDRAPT,MedDRASOC,SMQCode,SMQScope)
	)
	INSERT INTO #Drug1AllCountsSMQ 
	SELECT 
		DAC.Drecno1, 
		DAC.Drug1,
		DAC.Drecno2, 
		DAC.Drug2,
		DAC.MedDRASOC ,
		DAC.MedDRAPT , 
		DAC.SOC ,
		DAC.Reaction ,
		COALESCE(SMQMap.SMQ_CODE,-1),
		COALESCE(SMQName.SMQ_NAME,'-'),
		COALESCE(SC.Description,'-'),
		DAC.n___,
		DAC.n1__, 
		DAC.n_1_,
		DAC.n__1,
		DAC.n11_,
		DAC.n1_1,
		DAC.n_11,
		DAC.Observed,
		DAC.Expected
	FROM #Drug1AllCounts											DAC
	LEFT JOIN UMCReport20180102.ReferenceTermSMQ.SMQ_CONTENT		SMQMap			ON SMQMap.TERM_CODE = DAC.MedDRAPT AND SMQMap.TERM_STATUS = 'A'
	LEFT JOIN UMCReport20180102.ReferenceTermSMQ.SMQ_LIST			SMQName			ON SMQName.SMQ_CODE = SMQMap.SMQ_CODE
	LEFT JOIN UMCReport20180102.Lexicon.SMQScope					SC				ON SC.SMQScopeID = SMQMap.TERM_SCOPE

	GROUP BY 
		DAC.Drecno1, 
		DAC.Drug1,
		DAC.Drecno2, 
		DAC.Drug2,
		DAC.MedDRASOC,
		DAC.MedDRAPT, 
		DAC.SOC,
		DAC.Reaction,
		SMQMap.SMQ_CODE,
		SMQName.SMQ_NAME,
		SC.Description,
		DAC.n___,
		DAC.n1__, 
		DAC.n_1_,
		DAC.n__1,
		DAC.n11_,
		DAC.n1_1,
		DAC.n_11,
		DAC.Observed,
		DAC.Expected
	ORDER BY Observed DESC
	END

SELECT TOP(20) * FROM #Drug1AllCountsSMQ




SELECT DISTINCT
	AC.Drug1,
	AC.Drug2,
	AC.SOC,
	AC.Reaction,
	--CASE 
	--	WHEN AC.SMQName = 'Haemorrhage terms (excl laboratory terms) (SMQ)' THEN AC.SMQName 
	--	WHEN AC.SMQName = 'Haemorrhage laboratory terms (SMQ)' THEN AC.SMQName
	--	WHEN AC.SMQName = 'Haemorrhagic central nervous system vascular conditions (SMQ)' THEN AC.SMQName
	--	WHEN AC.SMQName = 'Conditions associated with central nervous system haemorrhages and cerebrovascular accidents (SMQ)' THEN AC.SMQName
	--	WHEN AC.SMQName = 'Gastrointestinal perforation, ulcer, haemorrhage, obstruction non-specific findings/procedures (SMQ)' THEN AC.SMQName
	--	WHEN AC.SMQName = 'Gastrointestinal haemorrhage (SMQ)' THEN AC.SMQName
	--	WHEN AC.SMQName = 'Liver-related coagulation and bleeding disturbances (SMQ)' THEN AC.SMQName
	--	ELSE '-' 
	--END AS SMQ,
	--CASE 
	--	WHEN AC.SMQName = 'Haemorrhage terms (excl laboratory terms) (SMQ)' THEN AC.SMQScope 
	--	WHEN AC.SMQName = 'Haemorrhage laboratory terms (SMQ)' THEN AC.SMQScope
	--	WHEN AC.SMQName = 'Haemorrhagic central nervous system vascular conditions (SMQ)' THEN AC.SMQScope
	--	WHEN AC.SMQName = 'Conditions associated with central nervous system haemorrhages and cerebrovascular accidents (SMQ)' THEN AC.SMQScope
	--	WHEN AC.SMQName = 'Gastrointestinal perforation, ulcer, haemorrhage, obstruction non-specific findings/procedures (SMQ)' THEN AC.SMQScope
	--	WHEN AC.SMQName = 'Gastrointestinal haemorrhage (SMQ)' THEN AC.SMQScope
	--	WHEN AC.SMQName = 'Liver-related coagulation and bleeding disturbances (SMQ)' THEN AC.SMQScope
	--	ELSE '-' 
	--END AS SMQScope,
	AC.Observed as NbObserved,
	AC.Expected as NbExpected, 
	ResearchProjects.dbo.ICoe(AC.Observed, AC.Expected) AS Omega, 
	ResearchProjects.dbo.ICoe025(AC.Observed, AC.Expected) AS Omega025,
	AC.n___ as NbVigiBase,
	AC.n1__ as NbDrug1,
	AC.n_1_ as NbDrug2,
	AC.n__1 as NbReaction,
	AC.n11_ as NbDrug1Drug2,
	AC.n1_1 as NbDrug1Reaction,
	AC.n_11 as NbDrug2Reaction
FROM #Drug1AllCountsSMQ AC
where ResearchProjects.dbo.ICoe025(AC.Observed, AC.Expected) > 0
		--AND AC.Reaction in (SELECT distinct MTI.MedDRAPTName COLLATE SQL_Latin1_General_CP1_CI_AS
		--									FROM UMCReport20180102.UMCReport.Report							Report
		--									JOIN UMCReport20180102.[UMCReport].[Reaction]					Reaction	ON Reaction.ReportID = Report.ReportID 
		--									JOIN UMCReport20180102.[UMCReport].[TB_MappedTermInformation]	MTI			ON MTI.[MappedReportedTermID] = Reaction.[UMCValidated_MappedReportedTermID] 
		--									LEFT JOIN UMCReport20180102.[UMCReport].[UMCCalculated_SMQ] ca ON report.ReportID = ca.ReportID 
		--									LEFT JOIN UMCReport.ReferenceTermSMQ.SMQ_LIST li ON ca.SMQ_CODE = li.SMQ_CODE 
		--									WHERE 
		--									Report.UMCCalculated_DeleteDate IS NULL AND Report.UMCCalculated_ForeignCase = 0
		--									AND (Report.UMCCalculated_PreferredICSR_ReportID IS NULL OR Report.UMCCalculated_PreferredICSR_ReportID = Report.ReportID)
		--									--AND li.[SMQ_code] in ('20000060', '20000038' ) 
		--									AND li.[SMQ_name] in ('haemorrhage laboratory terms (SMQ)', 'haemorrhage terms (excl laboratory terms) (SMQ)','Central nervous system haemorrhages and cerebrovascular conditions (SMQ)','Central nervous system vascular disorders (SMQ)' ) 
		--									AND ca.SMQscopeID = 2
		--								)
											
ORDER BY Omega025 DESC


--DROP TABLE #Drug1AllCounts
--DROP TABLE #DrugReactionCounts
--DROP TABLE #DrugDrugCounts
--DROP TABLE #SingleDrugCounts 
--DROP TABLE #ReportDrugList
--DROP TABLE #ReportReactionList