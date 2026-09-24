/*  
	Original script by defrost256 on GitHub
	https://github.com/defrost256/SplineExport/tree/master
	Edited by Avery Brown 9/24/2026
		I broke the function into two so that it can support multiple splines by adding additional Spline Components in Unreal Engine. 
		Then I refactored some of the resulting UMG code to support closed splines and fixed a bug where the relative offset 
		didn't work. There are a lot more calls to format in order to break up the lines into more readble and manageable 
		chunks. I also added an automatic unit scaling conversion, since I normally work in meters in Max and didn't 
		want to have to do any scaling. Lastly, I got rid of the rollout pop up and just have the script run on execute.
		The name still says "UE4", but I have only tested this in UE5.7.4. 
	
*/
	
macroScript UE4splineWriter
category:"UE4"
toolTip:"UE4 Spline Export"
buttonText:"UE4 Spline Copy"
Icon:#("Splines", 1)

(
	fn SysUnitToCentimeters = 
	(
		one_cm = units.decodeValue "1cm"
		
		return 1.0 / one_cm
	)
	
	fn ProcessSpline theSpline ind unit_conversion_factor =
	(
		vertPosArray = #()
		vertInArray = #()
		vertOutArray = #()

		--(ArriveTangent=(X=24.055420,Y=-42.968018,Z=0.000000),
		--LeaveTangent=(X=24.055420,Y=-42.968018,Z=0.000000),
		--InterpMode=CIM_CurveUser),
		--(InVal=1.000000,OutVal=(X=40.460693,Y=25.782288,Z=0.000000)

		splinePointTempl = "(InVal=%,OutVal=(X=%,Y=%,Z=%),"
		splineTanTempl = "ArriveTangent=(X=%,Y=%,Z=%),LeaveTangent=(X=%,Y=%,Z=%),InterpMode=CIM_CurveUser)"
		rotationNullStr = "(InVal=%,ArriveTangent=(X=0.000000,Y=0.000000,Z=0.000000,W=0.500000),LeaveTangent=(X=0.000000,Y=0.000000,Z=0.000000,W=0.500000),InterpMode=CIM_CurveAuto)"
		scaleOneStr = "(InVal=%,OutVal=(X=1.000000,Y=1.000000,Z=1.000000),InterpMode=CIM_CurveAuto)"
		reparamTableStr = "(InVal=%,OutVal=%)"
		
		outputStr = stringstream ""
		
		format "\t\tBegin Object Name=\"Spline_%\"\n\t\t\t\tSplineCurves=(Position=(Points=(" ind to:outputStr
		
		splineClosed = isClosed theSpline ind
		
		numPoints = numKnots theSpline ind
		
		-- Convert units to centimeters
		coord_update = [1.0, -1.0, 1.0] * unit_conversion_factor

		for v = 1 to numPoints do
		(
			vertPos = in coordsys world getKnotPoint theSpline ind v
			vertPos = vertPos * coord_update

			vertIn = in coordsys world getInVec theSpline ind v
			vertIn = vertIn * coord_update
			vertIn = (vertPos - vertIn) * 3.0

			vertOut = in coordsys world getOutVec theSpline ind v
			vertOut = vertOut * coord_update
			vertOut = (vertOut - vertPos) * 3.0

			if v != 1 do
				vertPos = vertPos - vertPosArray[1]

			append vertPosArray vertPos
			append vertInArray vertIn
			append vertOutArray vertOut
		)
		
		-- Relative Location
		rel_loc = (in coordsys world getKnotPoint theSpline ind 1) - theSpline.position
		rel_loc = rel_loc * coord_update
		
		print relative_attachment
		
		--Point strings
		for i = 1 to numPoints do
		(
			if i != 1 then
			(
				format splinePointTempl (i - 1) vertPosArray[i][1] vertPosArray[i][2] vertPosArray[i][3] to:outputStr
			)
			else
			(
				format "(" to:outputStr
			)
			
			format splineTanTempl vertInArray[i][1] vertInArray[i][2] vertInArray[i][3] vertOutArray[i][1] vertOutArray[i][2] vertOutArray[i][3] to:outputStr
			
			if i < numPoints do format "," to:outputStr
		)
		
		if (splineClosed) then
		(
			format "),bIsLooped=True,LoopKeyOffset=1.000000)," to:outputStr
		)
		else
		(
			format "))," to:outputStr
		)
		
		format "Rotation=(Points=((InterpMode=CIM_CurveAuto)," to:outputStr
		
		--Rotation Strings
		for i = 2 to numPoints do
		(
			format rotationNullStr (i - 1) to:outputStr
			
			if i < numPoints do format "," to:outputStr
		)
		
		if (splineClosed) then
		(
			format "),bIsLooped=True,LoopKeyOffset=1.000000)," to:outputStr
		)
		else
		(
			format "))," to:outputStr
		)
		
		format "Scale=(Points=((OutVal=(X=1.000000,Y=1.000000,Z=1.000000),InterpMode=CIM_CurveAuto)," to:outputStr

		for i = 2 to numPoints do
		(
			format scaleOneStr (i - 1) to:outputStr
			
			if i < numPoints do format "," to:outputStr
		)
		
		if (splineClosed) then
		(
			format "),bIsLooped=True,LoopKeyOffset=1.000000)," to:outputStr
		)
		else
		(
			format "))," to:outputStr
		)

		format "ReparamTable=(Points=(()," to:outputStr

		segLengths = getSegLengths theSpline ind cum:true
		for i = 0.1 to numPoints - 0.99 by 0.1 do
		(
			currentSegAndLength = findLengthSegAndParam theSpline ind (i / numPoints)
			
			format reparamTableStr (segLengths[currentSegAndLength[1] + (numPoints - 1)] * currentSegAndLength[2]) i to:outputStr

			if i < (numPoints - 1.05) do format "," to:outputStr
		)

		format ")))\n\t\t\t\tbSplineHasBeenEdited=True\n\t\t\t\tbClosedLoop=True\n\t\t\t\tbAllowDiscontinuousSpline=True\n" to:outputStr
		format "\t\t\t\tAttachParent=\"SceneComponent\'Scene\'\"\n" to:outputStr
		format "\t\t\t\tRelativeLocation=(X=%,Y=%,Z=%)\n" rel_loc[1] rel_loc[2] rel_loc[3] to:outputStr
		format "\t\t\t\tCreationMethod=Instance\n\t\t\tEnd Object\n" to:outputStr
		
		return outputStr
	)
	
	fn SplineCOPY =
	(
		unit_conversion_factor = SysUnitToCentimeters()
		
		outputStr = stringstream ""
		
		--Initialize Actor
		format "Begin Map\n\tBegin Level\n\t\tBegin Actor Class=Actor Name=Spline\n" to:outputStr
		
		-- Create Scene Component
		format "\t\t\tBegin Object Class=SceneComponent Name=\"Scene\"\n\t\t\tEnd Object\n" to:outputStr
		
		spline_object = convertToSplineShape $
		spline_object = $
		
		-- Define Scene Component
		format "\t\tBegin Object Name=\"Scene\"\n" to:outputStr
		
		coord_update = [1.0, -1.0, 1.0] * unit_conversion_factor
		
		pos = spline_object.position * coord_update
		
		format "\t\tRelativeLocation=(X=%,Y=%,Z=%)\n\t\tEnd Object\n" pos.x pos.y pos.z to:outputStr
		
		num_splines = numSplines spline_object
		
		-- Spline Components
		for i = 1 to num_splines do
		(
			format "\t\t\tBegin Object Class=SplineComponent Name=\"Spline_%\"\n\t\t\tEnd Object\n" i to:outputStr
		)
		
		-- Spline Data
		for i = 1 to num_splines do
		(
			spline_str = ProcessSpline spline_object i unit_conversion_factor
			
			append outputStr (spline_str as string)
		)
		
		-- Actor Wrap Up
		format "\t\t\tRootComponent=SceneComponent'Scene'\n" to:outputStr
		format "\t\t\tActorLabel=\"%_00\"\n" spline_object.name to:outputStr
		
		for i = 1 to num_splines do
		(
			format "\t\t\tInstanceComponents(%)=SplineComponent'Spline_%'\n" (i - 1) i to:outputStr
		)
		
		format "\t\tEnd Actor\n\tEnd Level\nBegin Surface\nEnd Surface\nEnd Map" to:outputStr

		setClipBoardText outputStr
	)

	on execute do
	(
		SplineCOPY()
	)
)