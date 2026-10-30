// SPDX-License-Identifier: Apache-2.0
// Experimental single-node entry point for RustFS 1.0.4.

use rustfs::embedded::RustFSServerBuilder;
use std::{env, io, net::SocketAddr, path::Path};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let mut args = env::args().skip(1);
    let mut address: SocketAddr = "127.0.0.1:9000".parse()?;
    let mut volume = None;
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "server" => {}
            "--address" => address = args.next().ok_or_else(|| io::Error::other("missing address"))?.parse()?,
            "--help" | "-h" => {
                println!(
                    "rustfs-single [server] [--address IP:PORT] DATA_DIRECTORY\nRequires RUSTFS_ACCESS_KEY and RUSTFS_SECRET_KEY. One local disk only."
                );
                return Ok(());
            }
            "--version" => {
                println!("rustfs-single 1.0.4 experimental");
                return Ok(());
            }
            _ if !arg.starts_with('-') && volume.is_none() => volume = Some(arg),
            _ => return Err(io::Error::other("unknown argument or multiple volumes").into()),
        }
    }
    if address.port() == 0 {
        return Err(io::Error::other("port must be nonzero").into());
    }
    let volume = volume.ok_or_else(|| io::Error::other("DATA_DIRECTORY is required"))?;
    if volume.contains("://") || volume.contains('{') || volume.contains('}') {
        return Err(io::Error::other("only one local filesystem path is supported").into());
    }
    std::fs::create_dir_all(&volume)?;
    let volume = std::fs::canonicalize(Path::new(&volume))?;
    let access = env::var("RUSTFS_ACCESS_KEY")?;
    let secret = env::var("RUSTFS_SECRET_KEY")?;
    if access.is_empty() || secret.is_empty() {
        return Err(io::Error::other("credentials must be nonempty").into());
    }
    // Peer discovery is omitted, but local metadata still needs the node identity.
    rustfs_common::set_global_local_node_name(&address.to_string()).await;
    let server = RustFSServerBuilder::new()
        .address(address.to_string())
        .access_key(access)
        .secret_key(secret)
        .region(env::var("RUSTFS_REGION").unwrap_or_else(|_| "us-east-1".into()))
        .volume(volume.to_string_lossy().into_owned())
        .build()
        .await?;
    eprintln!("rustfs-single ready at {}", server.endpoint());
    #[cfg(unix)]
    {
        let mut terminate = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())?;
        tokio::select! { result = tokio::signal::ctrl_c() => result?, _ = terminate.recv() => {} }
    }
    #[cfg(not(unix))]
    tokio::signal::ctrl_c().await?;
    server.shutdown().await;
    Ok(())
}
