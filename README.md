# Electric Love
## installation
To setup everything and launch Gmsh with the pro file.
This will require internet to setup python virtual environment with 
gmsh and numpy.
```
make init mesh view
```

Initialize the python virtual env

```
make init
```

To (re-)generate the mesh and (re-)generate the `generated_common.pro`  based on the `config.toml`.

```
make mesh
```

To open gmsh with the .pro file

```
make view
```
