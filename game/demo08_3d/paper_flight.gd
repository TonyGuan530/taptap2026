extends RefCounted
## SI units, independent 3D position/orientation and aerodynamic panel forces.
## Lift curve is Addmix's MIT-licensed Godot Aerodynamic Physics implementation.
## q*S*Cl/Cd and r.cross(force) adapted from its ManualAeroSurface3D.
const LiftCurveSource := preload("res://demo08_3d/vendor/lift_curve.gd")
var lift_curve = LiftCurveSource.new()
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var orientation := Basis.IDENTITY
var angular_velocity := Vector3.ZERO
var panels: Array = []
var mass := 0.005
var com := Vector3.ZERO
var inertia := Vector3.ONE
var area := 0.0
var span := 0.2
var last_lift := 0.0
var last_drag := 0.0
var last_aoa := 0.0

func launch(paper, angle_deg: float, power: float) -> void:
	panels = paper.aerodynamic_panels()
	mass = paper.material_area()*0.080 # 80 g/m² stock; folding never removes mass.
	com = paper.mass_center()
	area = 0.0
	span = 0.0
	for face in paper.faces:
		for p in face: span=maxf(span,absf(p.x-com.x)*2.0)
	for panel in panels: area += float(panel.area)
	inertia=Vector3(mass*paper.length_m*paper.length_m/12.0,mass*(span*span+paper.length_m*paper.length_m)/12.0,mass*span*span/12.0)
	position=Vector3(0,1.5,0)
	var mean_normal := Vector3.ZERO
	for panel in panels: mean_normal += panel.normal*float(panel.area)
	orientation=Basis(Vector3.RIGHT,deg_to_rad(angle_deg))*Basis(Vector3.BACK,atan2(mean_normal.x,mean_normal.y))
	velocity=orientation*Vector3(0,0,-lerpf(4.0,16.0,clampf(power,0,1)))
	angular_velocity=Vector3.ZERO

func surface_force(normal: Vector3, relative: Vector3, panel_area: float) -> Vector3:
	var speed := relative.length()
	if speed<0.001: return Vector3.ZERO
	var direction := relative/speed
	var aoa := asin(clampf(-normal.dot(direction),-1,1))+deg_to_rad(1.0)
	var cl: float = lift_curve.sample_baked(rad_to_deg(aoa))
	var ar := maxf(span*span/maxf(area,0.00001),0.5)
	var cd := 0.018+cl*cl/(PI*ar*0.8)+1.2*sin(aoa)*sin(aoa)
	var q := 0.5*1.225*speed*speed*panel_area
	var lift_dir := direction.cross(normal).cross(direction).normalized()
	last_lift += q*cl
	last_drag += q*cd
	last_aoa = aoa
	return q*(lift_dir*cl-direction*cd)

func step(delta: float, wind := Vector3.ZERO, steering: float = 0.0, dive: bool = false) -> void:
	var steps := maxi(1,int(ceil(delta*240.0)))
	var dt := delta/steps
	for _i in steps:
		last_lift=0.0; last_drag=0.0
		var force := Vector3(0,-mass*9.81,0)
		var torque := Vector3.ZERO
		for panel in panels:
			var arm: Vector3 = orientation*(panel.center-com)
			var relative := velocity+angular_velocity.cross(arm)-wind
			var f := surface_force(orientation*panel.normal,relative,float(panel.area))
			force += f
			torque += arm.cross(f)
		var air := velocity-wind
		var q_area := 0.5*1.225*air.length_squared()*area
		var aoa := asin(clampf(-orientation.y.dot(air.normalized()),-1,1))
		# Empirical pitch stability and rate damping for a flexible paper glider.
		# These are aerodynamic moments, not assignment of pitch from a 2D path.
		torque -= orientation.x*q_area*0.30*0.12*aoa
		torque -= angular_velocity*q_area*0.30*0.035
		torque -= orientation.z*steering*q_area*span*0.05
		if dive: torque -= orientation.x*q_area*0.30*0.10
		var local_torque := orientation.transposed()*torque
		var angular_accel := Vector3(local_torque.x/maxf(inertia.x,0.000002),local_torque.y/maxf(inertia.y,0.000002),local_torque.z/maxf(inertia.z,0.000002))
		angular_velocity += orientation*angular_accel.limit_length(300.0)*dt
		angular_velocity=angular_velocity.limit_length(8.0)
		if angular_velocity.length()>0.00001:
			orientation=(Basis(angular_velocity.normalized(),angular_velocity.length()*dt)*orientation).orthonormalized()
		velocity += force/mass*dt
		position += velocity*dt
