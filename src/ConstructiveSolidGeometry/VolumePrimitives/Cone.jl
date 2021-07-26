"""
    struct Cone{T,CO,TR,TP} <: AbstractVolumePrimitive{T, CO}

T: Type of values, e.g. Float64
CO: ClosedPrimitive or OpenPrimitive <-> whether surface belongs to it or not

* `r::TR`: 
    * TR = Real -> Cylinder
    * TR = (Real, Real) -> Tube (r_in = r[1], r_out = r[2])
    * TR = ((Real,), (Real,)) Solid widening Cylinder  -> (r_bot = r[1][1], r_top = r[1][2])
    * TR = ((Real,Real), (Real,Real)) Solid widening Tube ->\n(r_bot_in = r[1][1], r_bot_out = r[1][2], r_top_in = r[2][1], r_top_out = r[2][2])
    * TR = (Nothing, (Real,Real)) Cone ->\n(r_bot_in = r_bot_out = 0, r_top_in = r[2][1], r_top_out = r[2][2])
    * TR = ((Real,Real), Nothing) Cone ->\n(r_bot_in = r[1][1], r_bot_out = r[1][2], r_top_in = r_top_out = 0)
    * ... (+ elliptical cases -> (a, b))
    * Not all are implemented yet

* `φ::TP`: 
    * TP = Nothing <-> Full in φ
    * ...
* `hZ::T`: half height/length of the cone
"""
@with_kw struct Cone{T,CO,TR,TP} <: AbstractVolumePrimitive{T, CO}
    r::TR = 1
    φ::TP = nothing
    hZ::T = 1

    origin::CartesianPoint{T} = zero(CartesianPoint{T})
    rotation::SMatrix{3,3,T,9} = one(SMatrix{3, 3, T, 9})
end

Cone{T,CO,TR,TP}( c::Cone{T,CO,TR,TP}; COT = CO,
            origin::CartesianPoint{T} = c.origin,
            rotation::SMatrix{3,3,T,9} = c.rotation) where {T,CO<:Union{ClosedPrimitive, OpenPrimitive},TR,TP} =
    Cone{T,COT,TR,TP}(c.r, c.φ, c.hZ, origin, rotation)

####################################################################
####################################################################


#=
___
   |
   |
   |
___|

=#
const Cylinder{T,CO} = Cone{T,CO,T,Nothing} # Full in φ
const PartialCylinder{T,CO} = Cone{T,CO,T,Tuple{T,T}} 

### Cylinder

function _in(pt::CartesianPoint, c::Cylinder{T,ClosedPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    az = abs(pt.z) 
    az <= c.hZ + csgtol && begin
        r = hypot(pt.x, pt.y) 
        r <= c.r + csgtol
    end
end
function _in(pt::CartesianPoint, c::Cylinder{T,OpenPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    abs(pt.z) < c.hZ - csgtol &&
    hypot(pt.x, pt.y) < c.r - csgtol
end

function surfaces(t::Cylinder{T}) where {T}
    bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
    top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
    mantle = ConeMantle{T,Tuple{T,T},Nothing,:inwards}((t.r, t.r), t.φ, t.hZ, t.origin, t.rotation)
    e_bot = CircularArea{T}(r = t.r, φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
    e_top = CircularArea{T}(r = t.r, φ = t.φ, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
    # normals of the surfaces show inside the volume primitives. 
    e_top, e_bot, mantle
end

### PartialCylinder

function _in(pt::CartesianPoint, c::PartialCylinder{T,ClosedPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    az = abs(pt.z) 
    az <= c.hZ + csgtol && begin
        r = hypot(pt.x, pt.y) 
        r <= c.r + csgtol && 
        _in_angular_interval_closed(atan(pt.y, pt.x), c.φ, csgtol = csgtol / r)
    end
end
function _in(pt::CartesianPoint, c::PartialCylinder{T,OpenPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    abs(pt.z) + csgtol < c.hZ && begin
        r = hypot(pt.x, pt.y) 
        csgtol + r < c.r &&
        _in_angular_interval_open(atan(pt.y, pt.x), c.φ, csgtol = csgtol / r)
    end
end

function surfaces(t::PartialCylinder{T}) where {T}
    bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
    top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
    mantle = PartialConeMantle{T,:inwards}((t.r, t.r), t.φ, t.hZ, t.origin, t.rotation)
    e_bot = PartialCircularArea{T}(r = t.r, φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
    e_top = PartialCircularArea{T}(r = t.r, φ = t.φ, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
    poly_l = _transform_into_global_coordinate_system(Quadrangle{T}((
        CartesianPoint(CylindricalPoint{T}(zero(T),  t.φ[1], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(zero(T),  t.φ[1], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}(    t.r,  t.φ[1], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}(    t.r,  t.φ[1], -t.hZ)) )), t)
    poly_r = _transform_into_global_coordinate_system(Quadrangle{T}((
        CartesianPoint(CylindricalPoint{T}(zero(T),  t.φ[2], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(    t.r,  t.φ[2], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(    t.r,  t.φ[2], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}(zero(T),  t.φ[2], +t.hZ)) )), t)
    # normals of the surfaces show inside the volume primitives. 
    (e_top, e_bot, mantle, poly_l, poly_r)
end

####################################################################
####################################################################

#=
___
   \
    \
_____\

=#
const VaryingCylinder{T,CO} = Cone{T,CO,Tuple{Tuple{T},Tuple{T}},Nothing} # Full in φ
const PartialVaryingCylinder{T,CO} = Cone{T,CO,Tuple{Tuple{T},Tuple{T}},Tuple{T,T}}

function _in(pt::CartesianPoint, c::VaryingCylinder{T,ClosedPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    az = abs(pt.z) 
    az <= c.hZ + csgtol && begin
        r = hypot(pt.x, pt.y) 
        rz = radius_at_z(c.hZ, c.r[1][1], c.r[2][1], pt.z)
        r <= rz + csgtol
    end
end
function _in(pt::CartesianPoint, c::VaryingCylinder{T,OpenPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    abs(pt.z) + csgtol < c.hZ &&
    csgtol + hypot(pt.x, pt.y) < radius_at_z(c.hZ, c.r[1][1], c.r[2][1], pt.z)
end

function surfaces(t::VaryingCylinder{T}) where {T}
    bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
    top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
    mantle = ConeMantle{T,Tuple{T,T},Nothing,:inwards}((t.r[1][1], t.r[2][1]), t.φ, t.hZ, t.origin, t.rotation)
    e_bot = CircularArea{T}(r = t.r[1][1], φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
    e_top = CircularArea{T}(r = t.r[2][1], φ = t.φ, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
    # normals of the surfaces show inside the volume primitives. 
    e_top, e_bot, mantle
end

function _in(pt::CartesianPoint, c::PartialVaryingCylinder{T,ClosedPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    az = abs(pt.z) 
    az <= c.hZ + csgtol && begin
        r = hypot(pt.x, pt.y) 
        rz = radius_at_z(c.hZ, c.r[1][1], c.r[2][1], pt.z)
        r <= rz + csgtol &&
        _in_angular_interval_closed(atan(pt.y, pt.x), c.φ, csgtol = csgtol / r)
    end
end
function _in(pt::CartesianPoint, c::PartialVaryingCylinder{T,OpenPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    abs(pt.z) + csgtol < c.hZ && begin
        r = hypot(pt.x, pt.y) 
        csgtol + r < radius_at_z(c.hZ, c.r[1][1], c.r[2][1], pt.z) &&
        _in_angular_interval_open(atan(pt.y, pt.x), c.φ, csgtol = csgtol / r)
    end
end

function surfaces(t::PartialVaryingCylinder{T}) where {T}
    bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
    top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
    mantle = ConeMantle{T,Tuple{T,T},Tuple{T,T},:inwards}((t.r[1][1], t.r[2][1]), t.φ, t.hZ, t.origin, t.rotation)
    e_bot = PartialCircularArea{T}(r = t.r[1][1], φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
    e_top = PartialCircularArea{T}(r = t.r[2][1], φ = t.φ, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
    poly_l = _transform_into_global_coordinate_system(Quadrangle{T}((
        CartesianPoint(CylindricalPoint{T}(zero(T),    t.φ[1], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(zero(T),    t.φ[1], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}( t.r[2][1], t.φ[1], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}( t.r[1][1], t.φ[1], -t.hZ)) )), t)
    poly_r = _transform_into_global_coordinate_system(Quadrangle{T}((
        CartesianPoint(CylindricalPoint{T}(zero(T),    t.φ[2], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}( t.r[1][1], t.φ[2], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}( t.r[2][1], t.φ[2], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}(zero(T),    t.φ[2], +t.hZ)) )), t)
    # normals of the surfaces show inside the volume primitives. 
    e_top, e_bot, mantle, poly_l, poly_r
end



####################################################################
####################################################################

#=
  ___
 /   \
/_____\

=#
const VaryingTube{T,CO} = Cone{T,CO,Tuple{Tuple{T,T},Tuple{T,T}},Nothing} # Full in φ
const PartialVaryingTube{T,CO} = Cone{T,CO,Tuple{Tuple{T,T},Tuple{T,T}},Tuple{T,T}}      

#(r_bot_in = r[1][1], r_bot_out = r[1][2], r_top_in = r[2][1], r_top_out = r[2][2])

function _in(pt::CartesianPoint, c::VaryingTube{T,ClosedPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    az = abs(pt.z)
    az <= c.hZ + csgtol && begin
        r = hypot(pt.x, pt.y)
        r_in = radius_at_z(c.hZ, c.r[1][1], c.r[2][1], pt.z)
        r_out = radius_at_z(c.hZ, c.r[1][2], c.r[2][2], pt.z)
        r_in - csgtol <= r  &&
        r <= r_out + csgtol
    end
end
function _in(pt::CartesianPoint, c::VaryingTube{T,OpenPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    abs(pt.z) + csgtol < c.hZ &&
    csgtol + radius_at_z(c.hZ, c.r[1][1], c.r[2][1], pt.z) < hypot(pt.x, pt.y) < radius_at_z(c.hZ, c.r[1][2], c.r[2][2], pt.z) - csgtol
end

function surfaces(t::VaryingTube{T}) where {T}
    bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
    top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
    inner_mantle = ConeMantle{T,Tuple{T,T},Nothing,:outwards}((t.r[1][1], t.r[2][1]), t.φ, t.hZ, t.origin, t.rotation)
    outer_mantle = ConeMantle{T,Tuple{T,T},Nothing,:inwards}( (t.r[1][2], t.r[2][2]), t.φ, t.hZ, t.origin, t.rotation)
    e_bot = Annulus{T}(r = (t.r[1][1], t.r[1][2]), φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
    e_top = Annulus{T}(r = (t.r[2][1], t.r[2][2]), φ = t.φ, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
    # normals of the surfaces show inside the volume primitives. 
    e_top, e_bot, inner_mantle, outer_mantle
end

function _in(pt::CartesianPoint, c::PartialVaryingTube{T,ClosedPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    az = abs(pt.z)
    az <= c.hZ + csgtol && begin
        r = hypot(pt.x, pt.y)
        r_in = radius_at_z(c.hZ, c.r[1][1], c.r[2][1], pt.z)
        r_out = radius_at_z(c.hZ, c.r[1][2], c.r[2][2], pt.z)
        r_in - csgtol <= r &&
        r <= r_out + csgtol &&
        _in_angular_interval_closed(atan(pt.y, pt.x), c.φ, csgtol = csgtol / r)
    end 
end
function _in(pt::CartesianPoint, c::PartialVaryingTube{T,OpenPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    abs(pt.z) + csgtol < c.hZ && begin
        r = hypot(pt.x, pt.y)
        csgtol + radius_at_z(c.hZ, c.r[1][1], c.r[2][1], pt.z) < r < radius_at_z(c.hZ, c.r[1][2], c.r[2][2], pt.z) - csgtol &&
        _in_angular_interval_open(atan(pt.y, pt.x), c.φ, csgtol = csgtol / r)
    end
end

function surfaces(t::PartialVaryingTube{T}) where {T}
    bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
    top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
    inner_mantle = ConeMantle{T,Tuple{T,T},Tuple{T,T},:outwards}((t.r[1][1], t.r[2][1]), t.φ, t.hZ, t.origin, t.rotation)
    outer_mantle = ConeMantle{T,Tuple{T,T},Tuple{T,T},:inwards}( (t.r[1][2], t.r[2][2]), t.φ, t.hZ, t.origin, t.rotation)
    e_bot = PartialAnnulus{T}(r = (t.r[1][1], t.r[1][2]), φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
    e_top = PartialAnnulus{T}(r = (t.r[2][1], t.r[2][2]), φ = t.φ, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
    poly_l = _transform_into_global_coordinate_system(Quadrangle{T}((
        CartesianPoint(CylindricalPoint{T}(t.r[1][1],  t.φ[1], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(t.r[2][1],  t.φ[1], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}(t.r[2][2],  t.φ[1], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}(t.r[1][2],  t.φ[1], -t.hZ)) )), t)
    poly_r = _transform_into_global_coordinate_system(Quadrangle{T}((
        CartesianPoint(CylindricalPoint{T}(t.r[1][1],  t.φ[2], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(t.r[1][2],  t.φ[2], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(t.r[2][2],  t.φ[2], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}(t.r[2][1],  t.φ[2], +t.hZ)) )), t)
    # normals of the surfaces show inside the volume primitives. 
    e_top, e_bot, inner_mantle, outer_mantle, poly_l, poly_r
end

####################################################################
####################################################################

#=

\
 \
__\

=#
const UpwardCone{T,CO} = Cone{T,CO,Tuple{Tuple{Nothing,T},Nothing},Nothing} # Full in φ
const PartialUpwardCone{T,CO} = Cone{T,CO,Tuple{Tuple{Nothing,T},Nothing},Tuple{T,T}} 

function _in(pt::CartesianPoint, c::UpwardCone{T,ClosedPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    az = abs(pt.z)
    az <= c.hZ + csgtol && begin
        r = hypot(pt.x, pt.y)
        r_out = radius_at_z(c.hZ, c.r[1][2], zero(T), pt.z)
        r <= r_out + csgtol
    end 
end
function _in(pt::CartesianPoint, c::UpwardCone{T,OpenPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    abs(pt.z) + csgtol < c.hZ &&
    hypot(pt.x, pt.y) + csgtol < radius_at_z(c.hZ, c.r[1][2], zero(T), pt.z)
end

function surfaces(t::UpwardCone{T}) where {T}
    bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
    outer_mantle = ConeMantle{T,Tuple{T,T},Nothing,:inwards}( (t.r[1][2], zero(T)), t.φ, t.hZ, t.origin, t.rotation)
    e_bot = CircularArea{T}(r = t.r[1][2], φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
    # normals of the surfaces show inside the volume primitives. 
    e_bot, outer_mantle
end

function _in(pt::CartesianPoint, c::PartialUpwardCone{T,ClosedPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    az = abs(pt.z)
    az <= c.hZ + csgtol && begin
        r = hypot(pt.x, pt.y)
        r_out = radius_at_z(c.hZ, c.r[1][2], zero(T), pt.z)
        r <= r_out + csgtol &&
        _in_angular_interval_closed(atan(pt.y, pt.x), c.φ, csgtol = csgtol / r)
    end 
end
function _in(pt::CartesianPoint, c::PartialUpwardCone{T,OpenPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    abs(pt.z) + csgtol < c.hZ && begin
        r = hypot(pt.x, pt.y)
        csgtol + r < radius_at_z(c.hZ, c.r[1][2], zero(T), pt.z) &&
        _in_angular_interval_open(atan(pt.y, pt.x), c.φ, csgtol = csgtol / r)
    end
end

function surfaces(t::PartialUpwardCone{T}) where {T}
    bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
    outer_mantle = ConeMantle{T,Tuple{T,T},Tuple{T,T},:inwards}( (t.r[1][2], zero(T)), t.φ, t.hZ, t.origin, t.rotation)
    e_bot = PartialCircularArea{T}(r = t.r[1][2], φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
    poly_l = _transform_into_global_coordinate_system(Triangle{T}((
        CartesianPoint(CylindricalPoint{T}(zero(T),  t.φ[1], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(zero(T),  t.φ[1], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}(t.r[1][2],  t.φ[1], -t.hZ)) )), t)
    poly_r = _transform_into_global_coordinate_system(Triangle{T}((
        CartesianPoint(CylindricalPoint{T}(zero(T),  t.φ[2], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(t.r[1][2],  t.φ[2], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(zero(T),  t.φ[2], +t.hZ)) )), t)
    # normals of the surfaces show inside the volume primitives. 
    e_bot, outer_mantle, poly_l, poly_r
end


####################################################################
####################################################################

#=
___
  /
 /
/

=#
const DownwardCone{T,CO} = Cone{T,CO,Tuple{Nothing,Tuple{Nothing,T}},Nothing} # Full in φ
const PartialDownwardCone{T,CO} = Cone{T,CO,Tuple{Nothing,Tuple{Nothing,T}},Tuple{T,T}} 


function _in(pt::CartesianPoint, c::DownwardCone{T,ClosedPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    az = abs(pt.z)
    az <= c.hZ + csgtol && begin
        r = hypot(pt.x, pt.y)
        r_out = radius_at_z(c.hZ, zero(T), c.r[2][2], pt.z)
        r <= r_out + csgtol
    end 
end
function _in(pt::CartesianPoint, c::DownwardCone{T,OpenPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    abs(pt.z) + csgtol < c.hZ &&
    hypot(pt.x, pt.y) + csgtol < radius_at_z(c.hZ, zero(T), c.r[2][2], pt.z)
end

function surfaces(t::DownwardCone{T}) where {T}
    top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
    outer_mantle = ConeMantle{T,Tuple{T,T},Nothing,:inwards}( (zero(T), t.r[2][2]), t.φ, t.hZ, t.origin, t.rotation)
    e_top = CircularArea{T}(r = t.r[2][2], φ = t.φ, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
    # normals of the surfaces show inside the volume primitives. 
    e_top, outer_mantle
end

function _in(pt::CartesianPoint, c::PartialDownwardCone{T,ClosedPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    az = abs(pt.z)
    az <= c.hZ + csgtol && begin
        r = hypot(pt.x, pt.y)
        r_out = radius_at_z(c.hZ, zero(T), c.r[2][2], pt.z)
        r <= r_out + csgtol &&
        _in_angular_interval_closed(atan(pt.y, pt.x), c.φ, csgtol = csgtol / r)
    end 
end
function _in(pt::CartesianPoint, c::PartialDownwardCone{T,OpenPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    abs(pt.z) + csgtol < c.hZ && begin
        r = hypot(pt.x, pt.y) 
        csgtol + r < radius_at_z(c.hZ, zero(T), c.r[2][2], pt.z) &&
        _in_angular_interval_open(atan(pt.y, pt.x), c.φ, csgtol = csgtol / r)
    end
end

function surfaces(t::PartialDownwardCone{T}) where {T}
    bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
    outer_mantle = ConeMantle{T,Tuple{T,T},Tuple{T,T},:inwards}( (t.r[2][2], zero(T)), t.φ, t.hZ, t.origin, t.rotation)
    e_bot = PartialCircularArea{T}(r = t.r[2][2], φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
    poly_l = _transform_into_global_coordinate_system(Triangle{T}((
        CartesianPoint(CylindricalPoint{T}(zero(T),  t.φ[1], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(zero(T),  t.φ[1], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}(t.r[2][2],  t.φ[1], -t.hZ)) )), t)
    poly_r = _transform_into_global_coordinate_system(Triangle{T}((
        CartesianPoint(CylindricalPoint{T}(zero(T),  t.φ[2], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(t.r[2][2],  t.φ[2], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(zero(T),  t.φ[2], +t.hZ)) )), t)
    # normals of the surfaces show inside the volume primitives. 
    e_bot, outer_mantle, poly_l, poly_r
end



####################################################################
####################################################################

#=

  /\
 /  \
/____\

=#
const TopClosedTube{T,CO} = Cone{T,CO,Tuple{Tuple{T,T},T},Nothing} # Full in φ
const PartialTopClosedTube{T,CO} = Cone{T,CO,Tuple{Tuple{T,T},T},Tuple{T,T}} 


function _in(pt::CartesianPoint, c::TopClosedTube{T,ClosedPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    az = abs(pt.z)
    az <= c.hZ + csgtol && begin
        r = hypot(pt.x, pt.y)
        r_in = radius_at_z(c.hZ, c.r[1][1], c.r[2], pt.z)
        r_out = radius_at_z(c.hZ, c.r[1][2], c.r[2], pt.z)
        r_in - csgtol <= r &&
        r <= r_out + csgtol 
    end
end
function _in(pt::CartesianPoint, c::TopClosedTube{T,OpenPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    abs(pt.z) + csgtol < c.hZ &&
    csgtol + radius_at_z(c.hZ, c.r[1][1], c.r[2], pt.z) < hypot(pt.x, pt.y) < radius_at_z(c.hZ, c.r[1][2], c.r[2], pt.z) - csgtol
end

function surfaces(t::TopClosedTube{T}) where {T}
    bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
    # top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
    inner_mantle = ConeMantle{T,Tuple{T,T},Nothing,:outwards}((t.r[1][1], t.r[2]), t.φ, t.hZ, t.origin, t.rotation)
    outer_mantle = ConeMantle{T,Tuple{T,T},Nothing,:inwards}( (t.r[1][2], t.r[2]), t.φ, t.hZ, t.origin, t.rotation)
    e_bot = Annulus{T}(r = (t.r[1][1], t.r[1][2]), φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
    # e_top = Annulus{T}(r = (t.r[2][1], t.r[2][2]), φ = t.φ, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
    # normals of the surfaces show inside the volume primitives. 
    e_bot, inner_mantle, outer_mantle
end

function _in(pt::CartesianPoint, c::PartialTopClosedTube{T,ClosedPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    az = abs(pt.z)
    az <= c.hZ + csgtol && begin
        r = hypot(pt.x, pt.y)
        r_in = radius_at_z(c.hZ, c.r[1][1], c.r[2], pt.z)
        r_out = radius_at_z(c.hZ, c.r[1][2], c.r[2], pt.z)
        r_in - csgtol <= r &&
        r <= r_out + csgtol &&
        _in_angular_interval_closed(atan(pt.y, pt.x), c.φ, csgtol = csgtol / r)
    end 
end
function _in(pt::CartesianPoint, c::PartialTopClosedTube{T,OpenPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    abs(pt.z) + csgtol < c.hZ && begin
        r = hypot(pt.x, pt.y)
        csgtol + radius_at_z(c.hZ, c.r[1][1], c.r[2], pt.z) < r < radius_at_z(c.hZ, c.r[1][2], c.r[2], pt.z) - csgtol &&
        _in_angular_interval_open(atan(pt.y, pt.x), c.φ, csgtol = csgtol / r)
    end
end

function surfaces(t::PartialTopClosedTube{T}) where {T}
    bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
    # top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
    inner_mantle = ConeMantle{T,Tuple{T,T},Tuple{T,T},:outwards}((t.r[1][1], t.r[2]), t.φ, t.hZ, t.origin, t.rotation)
    outer_mantle = ConeMantle{T,Tuple{T,T},Tuple{T,T},:inwards}( (t.r[1][2], t.r[2]), t.φ, t.hZ, t.origin, t.rotation)
    e_bot = PartialAnnulus{T}(r = (t.r[1][1], t.r[1][2]), φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
    # e_top = Annulus{T}(r = (t.r[2][1], t.r[2][2]), φ = t.φ, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
    poly_l = _transform_into_global_coordinate_system(Triangle{T}((
        CartesianPoint(CylindricalPoint{T}(t.r[1][1],  t.φ[1], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(   t.r[2],  t.φ[1], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}(t.r[1][2],  t.φ[1], -t.hZ)) )), t)
    poly_r = _transform_into_global_coordinate_system(Triangle{T}((
        CartesianPoint(CylindricalPoint{T}(t.r[1][1],  t.φ[2], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(t.r[1][2],  t.φ[2], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(   t.r[2],  t.φ[2], +t.hZ)) )), t)
    # normals of the surfaces show inside the volume primitives. 
    e_bot, inner_mantle, outer_mantle, poly_l, poly_r
end



####################################################################
####################################################################

#=

______
\    /
 \  /
  \/

=#
const BottomClosedTube{T,CO} = Cone{T,CO,Tuple{T,Tuple{T,T}},Nothing} # Full in φ
const PartialBottomClosedTube{T,CO} = Cone{T,CO,Tuple{T,Tuple{T,T}},Tuple{T,T}} 


function _in(pt::CartesianPoint, c::BottomClosedTube{T,ClosedPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    az = abs(pt.z)
    az <= c.hZ + csgtol && begin
        r = hypot(pt.x, pt.y)
        r_in = radius_at_z(c.hZ, c.r[1], c.r[2][1], pt.z)
        r_out = radius_at_z(c.hZ, c.r[1], c.r[2][2], pt.z)
        r_in - csgtol <= r &&
        r <= r_out + csgtol 
    end
end
function _in(pt::CartesianPoint, c::BottomClosedTube{T,OpenPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    abs(pt.z) + csgtol < c.hZ &&
    csgtol + radius_at_z(c.hZ, c.r[1], c.r[2][1], pt.z) < hypot(pt.x, pt.y) < radius_at_z(c.hZ, c.r[1], c.r[2][2], pt.z) - csgtol
end

function surfaces(t::BottomClosedTube{T}) where {T}
    # bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
    top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
    inner_mantle = ConeMantle{T,Tuple{T,T},Nothing,:outwards}((t.r[1], t.r[2][1]), t.φ, t.hZ, t.origin, t.rotation)
    outer_mantle = ConeMantle{T,Tuple{T,T},Nothing,:inwards}( (t.r[1], t.r[2][2]), t.φ, t.hZ, t.origin, t.rotation)
    # e_bot = Annulus{T}(r = (t.r[1][1], t.r[1][2]), φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
    e_top = Annulus{T}(r = (t.r[2][1], t.r[2][2]), φ = t.φ, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
    # normals of the surfaces show inside the volume primitives. 
    e_top, inner_mantle, outer_mantle
end

function _in(pt::CartesianPoint, c::PartialBottomClosedTube{T,ClosedPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    az = abs(pt.z)
    az <= c.hZ + csgtol && begin
        r = hypot(pt.x, pt.y)
        r_in = radius_at_z(c.hZ, c.r[1], c.r[2][1], pt.z)
        r_out = radius_at_z(c.hZ, c.r[1], c.r[2][2], pt.z)
        r_in - csgtol <= r &&
        r <= r_out + csgtol &&
        _in_angular_interval_closed(atan(pt.y, pt.x), c.φ, csgtol = csgtol / r)
    end 
end
function _in(pt::CartesianPoint, c::PartialBottomClosedTube{T,OpenPrimitive}; csgtol::T = csg_default_tol(T)) where {T} 
    abs(pt.z) + csgtol < c.hZ && begin
        r = hypot(pt.x, pt.y)
        csgtol + radius_at_z(c.hZ, c.r[1], c.r[2][1], pt.z) < r < radius_at_z(c.hZ, c.r[1], c.r[2][2], pt.z) - csgtol &&
        _in_angular_interval_open(atan(pt.y, pt.x), c.φ, csgtol = csgtol / r)
    end
end

function surfaces(t::PartialBottomClosedTube{T}) where {T}
    # bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
    top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
    inner_mantle = ConeMantle{T,Tuple{T,T},Tuple{T,T},:outwards}((t.r[1], t.r[2][1]), t.φ, t.hZ, t.origin, t.rotation)
    outer_mantle = ConeMantle{T,Tuple{T,T},Tuple{T,T},:inwards}( (t.r[1], t.r[2][2]), t.φ, t.hZ, t.origin, t.rotation)
    # e_bot = PartialAnnulus{T}(r = (t.r[1][1], t.r[1][2]), φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
    e_top = PartialAnnulus{T}(r = (t.r[2][1], t.r[2][2]), φ = t.φ, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
    poly_l = _transform_into_global_coordinate_system(Triangle{T}((
        CartesianPoint(CylindricalPoint{T}(t.r[2][1],  t.φ[1], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}(t.r[2][2],  t.φ[1], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}(   t.r[1],  t.φ[1], -t.hZ)) )), t)
    poly_r = _transform_into_global_coordinate_system(Triangle{T}((
        CartesianPoint(CylindricalPoint{T}(t.r[2][1],  t.φ[2], +t.hZ)),
        CartesianPoint(CylindricalPoint{T}(   t.r[1],  t.φ[2], -t.hZ)),
        CartesianPoint(CylindricalPoint{T}(t.r[2][2],  t.φ[2], +t.hZ)) )), t)
    # normals of the surfaces show inside the volume primitives. 
    e_top, inner_mantle, outer_mantle, poly_l, poly_r
end


####################################################################
####################################################################


function Geometry(::Type{T}, t::Type{Cone}, dict::AbstractDict, input_units::NamedTuple, transformations::Transformations{T}) where {T}
    length_unit = input_units.length
    angle_unit = input_units.angle
    origin = get_origin(T, dict, length_unit)
    rotation = get_rotation(T, dict, angle_unit)

    r = parse_r_of_primitive(T, dict, length_unit, Cone)
    φ = parse_φ_of_primitive(T, dict, angle_unit)

    hZ = if haskey(dict, "h")
        _parse_value(T, dict["h"], length_unit) / 2
    elseif haskey(dict, "z")
        z = parse_height_of_primitive(T, dict, length_unit)
        hZ = typeof(z) <: Real ? z : (z[2] - z[1])/2
        if z isa Real
            @warn "Deprecation warning: Field `z` for `Cone` is deprecated. 
                Use `h` instead to specify the height of the primitive."
        else # z isa Tuple
            @warn "Deprecation warning: Field `z` for `Cone` is deprecated. 
                Use `h` instead to specify the height of the primitive.
                There might be a conflict with the possible field `origin`:
                The `z` component of the origin of the primitive is overwritten by the `z`."
            origin = CartesianPoint{T}(origin[1], origin[2], mean(z))
       end
       hZ
    end

    cone = Cone{T, ClosedPrimitive, typeof(r), typeof(φ)}(
        r = r, 
        φ = φ, 
        hZ = hZ, 
        origin = origin,
        rotation = rotation
    )
    return transform(cone, transformations)
end


function Dictionary(c::Cone{T, <:Any, TR})::OrderedDict{String, Any} where {T, TR}
    dict = OrderedDict{String, Any}()
    name  = "tube"
    if TR <: Real
        dict["r"] = c.r
    elseif TR <: Tuple{<:Real, <:Real}
        dict["r"] = OrderedDict{String, Any}("from" => c.r[1], "to" => c.r[2])
    else
        name = "cone"
        dict["r"] = OrderedDict{String, Any}()
        dict["r"]["bottom"] = if c.r[1] isa Tuple{<:Real} 
            c.r[1][1]
        elseif isnothing(c.r[1])
            0
        else
            OrderedDict{String, Any}("from" => c.r[1][1], "to" => c.r[1][2])
        end
        dict["r"]["top"] = if c.r[2] isa Tuple{<:Real} 
            c.r[2][1]
        elseif isnothing(c.r[2])
            0
        else 
            OrderedDict{String, Any}("from" => c.r[2][1], "to" => c.r[2][2])
        end
    end
    if !isnothing(c.φ) dict["phi"] = OrderedDict("from" => string(c.φ[1])*"rad", "to" => string(c.φ[2])*"rad") end
    dict["h"] = 2*c.hZ
    if c.origin != zero(CartesianVector{T}) dict["origin"] = c.origin end
    if c.rotation != one(SMatrix{3,3,T,9}) dict["rotation"] = Dictionary(c.rotation) end
    OrderedDict{String, Any}(name => dict)
end

# Cylinder


# PartialCylinder






# Tube
# function _in(pt::CartesianPoint, c::Tube{T,ClosedPrimitive}) where {T} 
#     abs(pt.z) <= c.hZ &&
#     c.r[1] <= hypot(pt.x, pt.y) <= c.r[2]
# end
# function _in(pt::CartesianPoint, c::Tube{T,OpenPrimitive}) where {T} 
#     abs(pt.z) < c.hZ &&
#     c.r[1] < hypot(pt.x, pt.y) < c.r[2]
# end

# function surfaces(t::Tube{T}) where {T}
#     bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
#     top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
#     inner_mantle = ConeMantle{T}((t.r[1], t.r[1]), t.φ, t.hZ, t.origin, t.rotation)
#     outer_mantle = ConeMantle{T}((t.r[2], t.r[2]), t.φ, t.hZ, t.origin, t.rotation)
#     e_bot = Annulus{T}(r = t.r, φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
#     e_top = Annulus{T}(r = t.r, φ = t.φ, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
#     # normals of the surfaces show inside the volume primitives. 
#     e_top, e_bot, inner_mantle, outer_mantle
# end

# PartialTube
# function _in(pt::CartesianPoint, c::PartialTube{T,ClosedPrimitive}) where {T} 
#     abs(pt.z) <= c.hZ &&
#     c.r[1] <= hypot(pt.x, pt.y) <= c.r[2] &&
#     _in_angular_interval_closed(atan(pt.y, pt.x), c.φ)
# end
# function _in(pt::CartesianPoint, c::PartialTube{T,OpenPrimitive}) where {T} 
#     abs(pt.z) < c.hZ &&
#     c.r[1] < hypot(pt.x, pt.y) < c.r &&
#     _in_angular_interval_open(atan(pt.y, pt.x), c.φ)
# end

# function surfaces(t::PartialTube{T}) where {T}
#     bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
#     top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
#     inner_mantle = PartialConeMantle{T}((t.r[1], t.r[1]), t.φ, t.hZ, t.origin, t.rotation)
#     outer_mantle = PartialConeMantle{T}((t.r[2], t.r[2]), t.φ, t.hZ, t.origin, t.rotation)
#     e_bot = PartialAnnulus{T}(r = t.r, φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
#     e_top = PartialAnnulus{T}(r = t.r, φ = t.φ, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
#     poly_l = _transform_into_global_coordinate_system(Quadrangle{T}((
#         CartesianPoint(CylindricalPoint{T}( t.r[1], t.φ[1], -t.hZ)),
#         CartesianPoint(CylindricalPoint{T}( t.r[2], t.φ[1], -t.hZ)),
#         CartesianPoint(CylindricalPoint{T}( t.r[2], t.φ[1], +t.hZ)),
#         CartesianPoint(CylindricalPoint{T}( t.r[1], t.φ[1], +t.hZ)) )), t)
#     poly_r = _transform_into_global_coordinate_system(Quadrangle{T}((
#         CartesianPoint(CylindricalPoint{T}( t.r[2], t.φ[2], -t.hZ)),
#         CartesianPoint(CylindricalPoint{T}( t.r[2], t.φ[2], +t.hZ)),
#         CartesianPoint(CylindricalPoint{T}( t.r[1], t.φ[2], +t.hZ)),
#         CartesianPoint(CylindricalPoint{T}( t.r[1], t.φ[2], -t.hZ)) )), t)
#     # normals of the surfaces show inside the volume primitives. 
#     e_top, e_bot, inner_mantle, outer_mantle, poly_l, poly_r
# end

# VaryingTube
# function _in(pt::CartesianPoint, c::VaryingTube{T,ClosedPrimitive}) where {T} 
#     abs(pt.z) <= c.hZ &&
#     c.r[1] <= hypot(pt.x, pt.y) <= c.r[2]
# end
# function _in(pt::CartesianPoint, c::VaryingTube{T,OpenPrimitive}) where {T} 
#     abs(pt.z) < c.hZ &&
#     c.r[1] < hypot(pt.x, pt.y) < c.r[2]
# end

# function surfaces(t::VaryingTube{T}) where {T}
#     bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
#     top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
#     inner_mantle = CylinderMantle{T}(t.r[1], t.φ, t.hZ, t.origin, t.rotation)
#     outer_mantle = CylinderMantle{T}(t.r[2], t.φ, t.hZ, t.origin, t.rotation)
#     e_bot = Annulus{T}(r = t.r, φ = t.φ, origin = bot_center_pt, rotation = t.rotation)
#     e_top = Annulus{T}(r = t.r, φ = t.φ, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
#     # normals of the surfaces show inside the volume primitives. 
#     e_top, e_bot, inner_mantle, outer_mantle
# end


# function surfaces(t::VaryingTube{T,CO}) where {T,CO}
#     bot_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), -t.hZ), t) 
#     top_center_pt = _transform_into_global_coordinate_system(CartesianPoint{T}(zero(T), zero(T), +t.hZ), t) 
#     in_mantle  = ConeMantle{T,Tuple{T,T},Nothing}((t.r[1][1], t.r[2][1]), t.φ, t.hZ, t.origin, t.rotation)
#     out_mantle = ConeMantle{T,Tuple{T,T},Nothing}((t.r[1][2], t.r[2][2]), t.φ, t.hZ, t.origin, t.rotation)
#     e_bot = EllipticalSurface{T,Tuple{T,T},Nothing}(r = t.r[1], φ = nothing, origin = bot_center_pt, rotation = t.rotation)
#     e_top = EllipticalSurface{T,Tuple{T,T},Nothing}(r = t.r[2], φ = nothing, origin = top_center_pt, rotation = -t.rotation * RotZ{T}(π))
#     # normals of the surfaces show inside the volume primitives. 
#     e_top, e_bot, in_mantle, out_mantle
# end

# PartialVaryingTube