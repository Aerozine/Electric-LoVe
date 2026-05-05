PYTHON ?= ./gmsh/bin/python
GMSH   ?= gmsh
GETDP  ?= getdp

.PHONY: init mesh clean run_elec run_mag run_therm run_all postmax slides convergence picard view view_elec view_mag view_therm

init:
	python3 -m venv gmsh
	./gmsh/bin/pip install -r requirements.txt

mesh:
	$(PYTHON) geometry.py

run_elec: mesh
	$(GETDP) LoVe.pro -msh LoVe.msh -solve Electrodynamics -pos Post_Ele -v2
	python3 postmax.py

run_mag: mesh
	$(GETDP) LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 1 -solve Magnetoquasistatics -pos Post_Mag -v2
	python3 postmax.py

run_therm: mesh
	$(GETDP) LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 2 \
	  -solve Magnetothermal -pos Post_Thermal -v2
	$(GETDP) LoVe.pro -msh LoVe.msh -setnumber Flag_AnalysisType 2 \
	  -pos Post_MagTher -v2
	python3 postmax.py

postmax:
	python3 postmax.py

slides: postmax convergence picard
	typst compile slides.typ slides.pdf

convergence:
	$(PYTHON) mesh_convergence.py

picard:
	$(PYTHON) picard_convergence.py

run_all: run_elec run_mag run_therm postmax

clean:
	rm -rf *.db *.db.json *.msh *.pre *.res res *.csv \
	       generated_common.pro generated_geometry.geo \
	       LoVe.step LoVe.brep __pycache__

view:
	$(GMSH) LoVe.pro

view_elec: run_elec
	$(GMSH) LoVe.msh res/v.pos res/em.pos res/dm.pos res/e.pos res/jdm.pos res/jrm.pos res/jtm.pos

view_mag: run_mag
	$(GMSH) LoVe.msh res/az.pos res/b.pos res/bm.pos res/jz_inds.pos res/jm.pos

view_therm: run_therm
	$(GMSH) LoVe.msh res/temperature.pos res/heat_source.pos res/mt_bm.pos res/mt_jm.pos res/mt_losses_density.pos
