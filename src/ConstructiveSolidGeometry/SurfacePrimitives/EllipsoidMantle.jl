@with_kw struct EllipsoidMantle{T,TR,TP,TT,D} <: AbstractCurvedSurfacePrimitive{T}
    r::TR = 1
    φ::TP = nothing
    θ::TT = nothing

    origin::CartesianPoint{T} = zero(CartesianPoint{T})
    rotation::SMatrix{3,3,T,9} = one(SMatrix{3, 3, T, 9})
end

flip(em::EllipsoidMantle{T,TR,TP,TT,:inwards}) where {T,TR,TP,TT} = 
    EllipsoidMantle{T,TR,TP,TT,:outwards}(em.r, em.φ, em.θ, em.origin, em.rotation )

const FullSphereMantle{T,D} = EllipsoidMantle{T,T,Nothing,Nothing,D}
const FullEllipsoidMantle{T,D} = EllipsoidMantle{T,NTuple{3,T},Nothing,Nothing,D}

function lines(em::FullSphereMantle{T}) where {T} 
    ellipse_xy = Ellipse{T,T,Nothing}(r = em.r[1], φ = em.φ, origin = em.origin, rotation = em.rotation)
    ellipse_xz = Ellipse{T,T,Nothing}(r = em.r[1], φ = em.φ, origin = em.origin, rotation = em.rotation * RotX(T(π)/2))
    ellipse_yz = Ellipse{T,T,Nothing}(r = em.r[1], φ = em.φ, origin = em.origin, rotation = em.rotation * RotX(T(π)/2) * RotY(T(π)/2))
    (ellipse_xy, ellipse_xz, ellipse_yz)
end
function lines(em::FullEllipsoidMantle{T}) where {T} 
    ellipse_xy = Ellipse{T,NTuple{2, Tuple{T}},Nothing}(r = ((em.r[1],), (em.r[2],)), φ = em.φ, origin = em.origin, rotation = em.rotation)
    ellipse_xz = Ellipse{T,NTuple{2, Tuple{T}},Nothing}(r = ((em.r[1],), (em.r[3],)), φ = em.φ, origin = em.origin, rotation = em.rotation * RotX(T(π)/2))
    ellipse_yz = Ellipse{T,NTuple{2, Tuple{T}},Nothing}(r = ((em.r[2],), (em.r[3],)), φ = em.φ, origin = em.origin, rotation = em.rotation * RotX(T(π)/2) * RotY(T(π)/2))
    (ellipse_xy, ellipse_xz, ellipse_yz)
end

extremum(e::EllipsoidMantle{T,T}) where {T} = e.r
extremum(e::EllipsoidMantle{T,NTuple{3,T}}) where {T} = max(e.r...)

function normal(em::EllipsoidMantle{T,NTuple{3,T},TP,TT,:outwards}, pt::CartesianPoint{T}) where {T,TP,TT}
    # not normalized, do we want this?
    # Or wrap this into somehting like `normal(em, pt) = normalize(direction(em, pt))` ?
    p = _transform_into_object_coordinate_system(pt, em)
    obj_normal = CartesianPoint{T}(sign(p.x)*(p.x/em.r[1])^2, sign(p.y)*(p.y/em.r[2])^2, sign(p.z)*(p.z/em.r[3])^2) # We might want to store the inv(em.r) in the struct?
    CartesianVector(_transform_into_global_coordinate_system(obj_normal, em))
end
function normal(em::EllipsoidMantle{T,T,TP,TT,:outwards}, pt::CartesianPoint{T}) where {T,TP,TT}
    # not normalized, do we want this?
    # Or wrap this into somehting like `normal(em, pt) = normalize(direction(em, pt))` ?
    p = _transform_into_object_coordinate_system(pt, em)
    obj_normal = CartesianPoint{T}(sign(p.x)*(p.x/em.r)^2, sign(p.y)*(p.y/em.r)^2, sign(p.z)*(p.z/em.r)^2) # We might want to store the inv(em.r) in the struct?
    CartesianVector(_transform_into_global_coordinate_system(obj_normal, em))
end
normal(em::EllipsoidMantle{T,TR,TP,TT,:inwards}, pt::CartesianPoint{T}) where {T,TR,TP,TT} = -normal(flip(em), pt)

"""
    intersection(cm::EllipsoidMantle{T,NTuple{3,T}}, l::Line{T}) where {T}

The function will always return 2 CartesianPoint's.
If the line just touches the mantle, the two points will be the same. 
If the line does not touch the mantle at all, the two points will have NaN's as there coordinates.
"""
function intersection(em::EllipsoidMantle{T,NTuple{3,T}}, l::Line{T}) where {T}
    obj_l = _transform_into_object_coordinate_system(l, em) # direction is not normalized
    
    L1 = obj_l.origin.x
    L2 = obj_l.origin.y
    L3 = obj_l.origin.z
    D1 = obj_l.direction.x
    D2 = obj_l.direction.y
    D3 = obj_l.direction.z
    
    R1 = em.r[1]
    R2 = em.r[2]
    R3 = em.r[3]

    term3 = D1^2/R1^2 + D2^2/R2^2 + D3^2/R3^2
    term1 = ((2D1*L1)/R1^2 + (2D2*L2)/R2^2 + (2D3*L3)/R3^2)^2 - 4*term3*(L1^2/R1^2 + L2^2/R2^2 + L3^2/R3^2 - 1)
    term2 = -(2D1*L1)/R1^2 - (2D2*L2)/R2^2 - (2D3*L3)/R3^2

    term1 = term1 < 0 ? sqrt(abs(term1)) : sqrt(term1)

    λ1 = (term2 - term1) / 2term3
    λ2 = (term2 + term1) / 2term3

    ints1 = obj_l.origin + λ1 * obj_l.direction 
    ints2 = obj_l.origin + λ2 * obj_l.direction 
    return _transform_into_global_coordinate_system(ints1, em), 
           _transform_into_global_coordinate_system(ints2, em)
end
"""
    intersection(cm::EllipsoidMantle{T,T}, l::Line{T}) where {T}

The function will always return 2 CartesianPoint's.
If the line just touches the mantle, the two points will be the same. 
If the line does not touch the mantle at all, the two points will have NaN's as there coordinates.
"""
function intersection(em::EllipsoidMantle{T,T}, l::Line{T}) where {T}
    obj_l = _transform_into_object_coordinate_system(l, em) # direction is not normalized
    
    L1 = obj_l.origin.x
    L2 = obj_l.origin.y
    L3 = obj_l.origin.z
    D1 = obj_l.direction.x
    D2 = obj_l.direction.y
    D3 = obj_l.direction.z
    
    R = em.r

    term3 = D1^2 + D2^2 + D3^2
    term1 = (2D1*L1 + 2D2*L2 + 2D3*L3)^2 - 4*term3*(L1^2 + L2^2 + L3^2 - R^2)
    term2 = -D1*L1 - D2*L2 - D3*L3
    
    if term1 < 0 term1 = abs(term1) end

    λ1 = (term2 - sqrt(term1)/2) / term3
    λ2 = (term2 + sqrt(term1)/2) / term3

    ints1 = obj_l.origin + λ1 * obj_l.direction 
    ints2 = obj_l.origin + λ2 * obj_l.direction 
    return _transform_into_global_coordinate_system(ints1, em), 
           _transform_into_global_coordinate_system(ints2, em)
end


# distance_to_surface(point::CylindricalPoint{T}, s::SphereMantle{T}) where {T} = abs(hypot(point.r, point.z) - s.r)

# distance_to_surface(point::CartesianPoint{T}, s::SphereMantle{T}) where {T} = abs(norm(point) - s.r)