using SciBmadUtils
using Beamlines
using OrderedCollections
using YAML
using Test

# Returns the entry named `name` in the facility of the PALS tree `pals`
function facility_entry(pals, name)
    for item in pals["PALS"]["facility"]
        haskey(item, name) && return item[name]
    end
    error("No facility entry named $name")
end

@testset "SciBmadUtils.jl" begin
    @testset "Elements" begin
        a = 0.36
        qf = Quadrupole(name="qf", L=0.5, Kn1=DefExpr(()->a), tilt1=0.1)
        d = Drift(name="d", L=1, x1_limit=-0.02, x2_limit=0.02, aperture_shape=ApertureShape.Rectangular)
        qd = Quadrupole(name="qd", L=0.5, Kn1L=-0.18, x_offset=1e-3, tilt=0.01)
        b = SBend(name="b", L=2.0, g_ref=0.01, e1=0.1, edge1_int=0.05)
        bk = SBend(name="bk", L=2.0, g_ref=0.01, Kn0=0.01)
        p = Patch(name="p", dx=0.1, dz_rot=0.02, dt=1e-9)
        m = Marker(name="m", description="a marker", alias="mm")
        rf = RFCavity(name="rf", L=1, voltage=1e6, rf_frequency=5e8, phi0=0.3, traveling_wave=true)
        crab = CrabCavity(name="crab", L=0.2, voltage=1e5, harmon=10)
        hk = HKicker(name="hk", Kn0=1e-4, ignore_params=[BMultipoleParams])
        el = Multipole(name="el", En1=2.0, etilt1=0.2)
        bl = Beamline([qf, d, qd, b, bk, p, m, rf, crab, hk, el], species_ref=Species("electron"), E_ref=18e9)
        pals = to_pals(bl)

        @test facility_entry(pals, "qf") == OrderedDict(
            "kind" => "Quadrupole", "length" => 0.5,
            "MagneticMultipoleP" => OrderedDict("Kn1" => 0.36, "tilt1" => 0.1),
        )
        # DefExprs are evaluated when translating
        a = 0.5
        @test facility_entry(to_pals(bl), "qf")["MagneticMultipoleP"]["Kn1"] == 0.5

        @test facility_entry(pals, "d")["ApertureP"] == OrderedDict(
            "x_min" => -0.02, "x_max" => 0.02, "shape" => "RECTANGULAR", "aperture_shifts_with_body" => true,
        )
        @test facility_entry(pals, "qd")["BodyShiftP"] == OrderedDict("x_offset" => 1e-3, "z_rot" => 0.01)
        @test facility_entry(pals, "qd")["MagneticMultipoleP"] == OrderedDict("Kn1L" => -0.18)

        @test facility_entry(pals, "b")["kind"] == "Bend"
        @test facility_entry(pals, "b")["BendP"] == OrderedDict(
            "g_ref" => 0.01, "e1" => 0.1, "edge1_int" => 0.05, "Kn0_from_g_ref" => false,
        )
        @test !haskey(facility_entry(pals, "bk")["BendP"], "Kn0_from_g_ref")

        @test facility_entry(pals, "p")["PatchP"] == OrderedDict(
            "SciBmad_dt" => 1e-9, "x_offset" => 0.1, "z_rot" => 0.02, "user_sets_length" => true,
        )
        @test facility_entry(pals, "m")["MetaP"] == OrderedDict("alias" => "mm", "description" => "a marker")
        @test facility_entry(pals, "rf")["RFP"] == OrderedDict(
            "frequency" => 5e8, "voltage" => 1e6, "phase" => 0.3, "cavity_type" => "TRAVELING_WAVE",
        )
        @test facility_entry(pals, "crab")["kind"] == "CrabCavity"
        @test facility_entry(pals, "crab")["RFP"] == OrderedDict("harmon" => 10, "voltage" => 1e5)
        @test facility_entry(pals, "hk")["kind"] == "Kicker"
        @test facility_entry(pals, "hk")["SciBmad_ignore_params"] == ["MagneticMultipoleP"]
        @test facility_entry(pals, "el")["ElectricMultipoleP"] == OrderedDict("En1" => 2.0, "tilt1" => 0.2)

        # SciBmad extensions are declared
        @test haskey(pals["PALS"]["extension_labels"]["prefixes"], "SciBmad_")
    end

    @testset "Lattice structure" begin
        d = Drift(name="d", L=1)
        u = Drift(L=0.3)
        q = Quadrupole(name="q.1", L=0.5, Kn1=0.3)
        bl1 = Beamline([d, u, q, u, Drift(L=0.4), Drift(name="d", L=2)], species_ref=Species("proton"), pc_ref=1e9)
        bl2 = Beamline([d, q], dE_ref=1e6)
        lat = Lattice([Branch([bl1, bl2], name="ring")], name="my_lattice")
        pals = to_pals(lat)
        facility = pals["PALS"]["facility"]

        @test pals["PALS"]["version"] === nothing
        @test !haskey(pals["PALS"], "extension_labels")
        @test facility_entry(pals, "ring_begin") == OrderedDict(
            "kind" => "BeginningEle",
            "ReferenceP" => OrderedDict("species_ref" => "proton", "pc_ref" => 1e9),
        )
        @test facility_entry(pals, "ring_ref_change") == OrderedDict(
            "kind" => "ReferenceChange", "ReferenceChangeP" => OrderedDict("dE_ref" => 1e6),
        )
        # Invalid characters are replaced, unnamed elements are given names, copies of
        # the same unnamed element share a name, and a later element with the same name
        # but different parameters only gives what differs.
        @test facility_entry(pals, "ring")["line"] == [
            "ring_begin", "d", "drift", "q_1", "drift", "drift_1",
            OrderedDict("d" => OrderedDict("length" => 2)),
            "ring_ref_change", "d", "q_1",
        ]
        @test facility_entry(pals, "my_lattice") == OrderedDict("kind" => "Lattice", "branches" => ["ring"])
        # Elements are defined first, then the BeamLines, then the Lattice
        @test first(keys(last(facility))) == "my_lattice"

        # Parameter groups missing from a later element with the same name are unset
        d2 = Drift(name="d", L=1)
        bl = Beamline([Drift(name="d", L=1, x_offset=0.1), d2])
        line = facility_entry(to_pals(bl; name="line"), "line")["line"]
        @test line[3] == OrderedDict("d" => OrderedDict("BodyShiftP" => OrderedDict("x_offset" => nothing)))

        # Branch names that clash with element names are made unique
        bl = Beamline([Drift(name="b1", L=1)])
        @test to_pals(Lattice([bl]))["PALS"]["facility"][end]["lattice"]["branches"] == ["b1_1"]
    end

    @testset "write_pals" begin
        bl = Beamline([Drift(name="d", L=1), Quadrupole(name="q", L=0.5, Kn1=0.3)],
                      species_ref=Species("electron"), E_ref=1e9)
        lat = Lattice([bl], name="lat")
        mktempdir() do dir
            file = joinpath(dir, "lat.pals.yaml")
            write_pals(file, lat)
            @test YAML.load_file(file; dicttype=OrderedDict{String,Any}) == to_pals(lat)
        end
    end
end
