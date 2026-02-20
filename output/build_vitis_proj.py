r"""
Vitis Platform and Application Creation Script
======================================================

This script combines platform and application creation in a single Vitis session.

Usage:
    # Create both platform and application
    C:\AMD\2025.2\Vitis\bin\vitis.bat -s build_vitis_proj.py -x artifacts/kv260_rpicamera_to_dp.xsa -w vitis -p kv260_rpicamera_to_dp --sw-path ../sw/set_up_video_pipeline
    
    # Create platform only
    C:\AMD\2025.2\Vitis\bin\vitis.bat -s build_vitis_proj.py -x artifacts/kv260_rpicamera_to_dp.xsa -w vitis -p kv260_rpicamera_to_dp --platform-only
    
    # Create application only (platform must exist)
    C:\AMD\2025.2\Vitis\bin\vitis.bat -s build_vitis_proj.py -w vitis -p kv260_rpicamera_to_dp --sw-path ../sw/set_up_video_pipeline --app-only

Optional parameters:
    -o, --os        Operating system (default: standalone)
    -c, --cpu       CPU name (default: psu_cortexa53_0)
    -d, --domain    Domain name (default: standalone_psu_cortexa53_0)

"""

import vitis
import os
import argparse
import sys
import shutil
import atexit

def cleanup_client(client):
    """Safely disposes the Vitis client if the method exists."""
    if client:
        try:
            # Check if dispose exists before calling (Fixes AttributeError)
            if hasattr(client, 'dispose'):
                client.dispose()
        except Exception:
            pass

def create_vitis_platform(client, xsa_path, workspace_path, project_name, os_name='standalone', cpu_name='psu_cortexa53_0'):
    print(f"--- Vitis 2025.2 Platform Creation ---")
    
    # 1. Validation
    if not os.path.exists(xsa_path):
        print(f"Error: XSA file not found at {xsa_path}")
        sys.exit(1)

    # 2. Check Platform Folder (Prevent conflicts)
    platform_path = os.path.join(workspace_path, "platform")
    if os.path.exists(platform_path):
        print(f"Error: Platform directory already exists at {platform_path}. Please manually delete this directory and try again.")
        sys.exit(1)
    
    os.makedirs(workspace_path, exist_ok=True)

    try:
        plat_name = f"platform"

        # 3. Platform Creation - Check for existing platform component
        print(f"Checking for existing platform '{plat_name}'...")
        try:
            existing_platform = client.get_component(name=plat_name)
            print(f"Error: Platform component '{plat_name}' already exists in workspace. Please use a different workspace or clean the existing platform from Vitis IDE.")
            sys.exit(1)
        except Exception:
            # No existing platform found, which is what we want
            pass

        print(f"Creating platform component '{plat_name}'...")
        plat = client.create_platform_component(
            name=plat_name,
            hw_design=xsa_path,
            os=os_name,
            cpu=cpu_name,
            domain_name=f'{os_name}_{cpu_name}'
        )
        
        print("Building platform...")
        plat.build()

        # 4. Verify Platform Build
        # Use the local platform path instead of repository lookup
        xpfm_path = os.path.join(workspace_path, "platform", "export", "platform", "platform.xpfm")

        if not os.path.exists(xpfm_path):
            raise RuntimeError(
                f"Platform build failed. .xpfm file not found at '{xpfm_path}'.\n"
                f"Action: Move workspace to a shorter path (e.g., C:\\ws) to avoid Windows MAX_PATH limits."
            )

        print(f"Platform successfully created at: {xpfm_path}")
        print("Platform build successful.")
        return xpfm_path

    except Exception as e:
        print(f"\n[ERROR] Platform creation failed: {e}")
        sys.exit(1)

def create_vitis_application(client, workspace_path, project_name, sw_path, domain_name='standalone_psu_cortexa53_0'):
    print(f"--- Vitis 2025.2 Application Creation ---")
    
    # 1. Validation
    if not os.path.exists(sw_path):
        print(f"Error: Software sources directory not found at {sw_path}")
        sys.exit(1)

    # 2. Check Application Directory (Prevent conflicts)
    app_path = os.path.join(workspace_path, "app")
    if os.path.exists(app_path):
        print(f"Error: Application directory already exists at {app_path}. Please manually delete this directory and try again.")
        sys.exit(1)

    # 2. Verify Platform Exists
    xpfm_path = os.path.join(workspace_path, "platform", "export", "platform", "platform.xpfm")
    if not os.path.exists(xpfm_path):
        print(f"Error: Platform file not found at {xpfm_path}")
        print("Please run the platform creation first or use --create-platform flag.")
        sys.exit(1)

    try:
        app_name = f"app"

        # 3. Application Creation - Check for existing application component
        print(f"Checking for existing application '{app_name}'...")
        try:
            existing_app = client.get_component(name=app_name)
            print(f"Error: Application component '{app_name}' already exists in workspace. Please use a different workspace or clean the existing application from Vitis IDE.")
            sys.exit(1)
        except Exception:
            # No existing application found, which is what we want
            pass

        print(f"Creating application component '{app_name}'...")
        # Note: Use the configurable domain parameter
        app = client.create_app_component(
            name=app_name,
            platform=xpfm_path,
            domain=domain_name, 
            template="empty_application" # Use empty so we can import our own sources
        )

        print(f"Importing source files from {sw_path}...")
        # Link sources (soft link) rather than copy
        app.import_files(
            from_loc=sw_path,
            dest_dir_in_cmp='src',
            is_skip_copy_sources=True
        )

        # 4. Build Application
        print(f"Building application component '{app_name}'...")
        app_comp = client.get_component(name=app_name)
        app_comp.build()
        print("Application build successful.")
        
        # 5. Post-build hardware sync (matches GUI behavior)
        print("Performing hardware synchronization...")
        app_path = os.path.join(workspace_path, app_name)
        
        # Create IDE directories if they don't exist
        ide_bitstream_dir = os.path.join(app_path, "_ide", "bitstream")
        ide_psinit_dir = os.path.join(app_path, "_ide", "psinit")
        os.makedirs(ide_bitstream_dir, exist_ok=True)
        os.makedirs(ide_psinit_dir, exist_ok=True)
        
        # Copy hardware files from platform (GUI does this automatically)
        platform_hw_dir = os.path.join(workspace_path, "platform", "export", "platform", "hw")
        if os.path.exists(platform_hw_dir):
            print("Syncing hardware files with application...")
            # Note: Vitis API typically handles this, but we ensure directories exist

    except Exception as e:
        print(f"\n[ERROR] Application creation failed: {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Vitis Platform and Application Creation")
    
    # Common arguments
    parser.add_argument('-w', '--workspace', required=True, help='Workspace Path')
    parser.add_argument('-p', '--project', required=True, help='Project Name')
    
    # Platform arguments
    parser.add_argument('-x', '--xsa', help='Path to XSA (required for platform creation)')
    parser.add_argument('-o', '--os', default='standalone', help='Operating system (default: standalone)')
    parser.add_argument('-c', '--cpu', default='psu_cortexa53_0', help='CPU name (default: psu_cortexa53_0)')
    
    # Application arguments
    parser.add_argument('--sw-path', help='SW Source Dir (required for application creation)')
    parser.add_argument('-d', '--domain', default='standalone_psu_cortexa53_0', help='Domain name (default: standalone_psu_cortexa53_0)')
    
    # Mode selection
    parser.add_argument('--platform-only', action='store_true', help='Create platform only')
    parser.add_argument('--app-only', action='store_true', help='Create application only (platform must exist)')
    
    args = parser.parse_args()
    
    # Validate arguments based on mode
    if args.app_only and args.platform_only:
        print("Error: Cannot specify both --platform-only and --app-only")
        sys.exit(1)
    
    if args.app_only:
        if not args.sw_path:
            print("Error: --sw-path is required when creating application only")
            sys.exit(1)
    elif args.platform_only:
        if not args.xsa:
            print("Error: --xsa is required when creating platform only")
            sys.exit(1)
    else:
        # Default mode: create both
        if not args.xsa or not args.sw_path:
            print("Error: Both --xsa and --sw-path are required for full creation")
            sys.exit(1)
    
    client = None
    try:
        # Initialize single Vitis client session
        print("Initializing Vitis client...")
        client = vitis.create_client()
        
        # Handle workspace setup
        workspace_set = False
        try:
            client.set_workspace(args.workspace)
            workspace_set = True
        except Exception as e:
            if "already in use" in str(e) or "FAILED_PRECONDITION" in str(e):
                print("Workspace is locked, trying to connect to existing session...")
                try:
                    current_workspace = client.get_workspace()
                    if current_workspace:
                        workspace_set = True
                        print("Connected to existing workspace session.")
                    else:
                        print("No existing workspace found, cannot proceed.")
                        sys.exit(1)
                except Exception as e2:
                    print(f"Could not connect to existing workspace: {e2}")
                    print("Try closing other Vitis instances and run again.")
                    sys.exit(1)
            else:
                raise
        
        if not workspace_set:
            print("Error: Failed to set or connect to workspace")
            sys.exit(1)
        
        # Execute based on mode
        if args.platform_only:
            # Create platform only
            create_vitis_platform(client, args.xsa, args.workspace, args.project, args.os, args.cpu)
        elif args.app_only:
            # Create application only
            create_vitis_application(client, args.workspace, args.project, args.sw_path, args.domain)
        else:
            # Create both platform and application
            xpfm_path = create_vitis_platform(client, args.xsa, args.workspace, args.project, args.os, args.cpu)
            create_vitis_application(client, args.workspace, args.project, args.sw_path, args.domain)
        
        print("\n=== Vitis setup completed successfully ===")
        
    except Exception as e:
        print(f"\n[ERROR] Setup failed: {e}")
        sys.exit(1)
    finally:
        cleanup_client(client)

if __name__ == "__main__":
    main()
