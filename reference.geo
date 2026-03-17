//=================================================
// Geometrical data
//=================================================

mm = 1e-3;

dc = 18.4*mm; // Diameter of conductor
dist_cab = 32.0*mm; // distance between conductors
h = dist_cab * Sin(Pi/3); // height of equilateral triangle

tsp  = 4*mm;  // Thickness of Steel pipe

dtot = 135*mm; // Outer diameter cable
dinf = 5*dtot; // Electromagnetic analysis

//=================================================

SetFactory("OpenCASCADE");

x0 = 0; y0 = 2*h/3;
x1 = -dist_cab/2; y1 = -h/3;
x2 =  dist_cab/2; y2 = -h/3;

// cable wires
Disk(news) = {x0, y0, 0., dc/2};
Disk(news) = {x1, y1, 0., dc/2};
Disk(news) = {x2, y2, 0., dc/2};

// limit dielectric material
Disk(news) = {0., 0., 0., dtot/2-tsp};
// limit steel pipe
Disk(news) = {0., 0., 0., dtot/2};

// around the cable
// boundary computational domain
Disk(news) = {0., 0., 0., dinf/2};

// Intersect all surfaces (== Surface{:}) created till here
// and delete those that are destroyed
BooleanFragments{Surface{:}; Delete;}{}

// ===========================================
// Physical regions => link to pro-file and FE
// ===========================================

Physical Surface("wire 1", 11) = 1;
Physical Surface("wire 2", 12) = 2;
Physical Surface("wire 3", 13) = 3;

Physical Line("bnd wire 1", 110) = Boundary{Surface{1};};
Physical Line("bnd wire 2", 120) = Boundary{Surface{2};};
Physical Line("bnd wire 3", 130) = Boundary{Surface{3};};

Physical Surface("semiconductor", 20) = 4;
Physical Surface("steel pipe", 30) = 5;
Physical Surface("ground",     40) = 6;

Physical Line("Outer boundary", 50) = 6;


// Adjusting some characteristic lengths

DefineConstant[ cl = {dtot/3, Name "Mesh size", Visible 0} ];

// The order of the following instructions may influence the result of the mesh
// If you have surfaces that have common lines and therefore points, then the last instruction prevails

MeshSize { PointsOf{ Surface{4,5,6}; } } = cl/8;
MeshSize { PointsOf{ Surface{1,2,3}; } } = cl/16;

MeshSize { PointsOf{ Line{6};} } = cl; // outer boundary of EMdom


// Some colours, just for aesthetics...
// You may use elementary geometrical or physical entities
Recursive Color Cyan {Physical Surface{40};}
Recursive Color Green {Physical Surface{30};}
Recursive Color Gold {Physical Surface{20};}
Recursive Color Red {Physical Surface{11,12,13};}
