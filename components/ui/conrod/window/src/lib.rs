extern crate capnp;

#[macro_use]
extern crate rustfbp;

use std::thread;

component! {
    ui_conrod_window,
    inputs(input: any),
    inputs_array(),
    outputs(output: any, magic: any),
    outputs_array(output: any),
    option(),
    acc(),
    fn run(&mut self) -> Result<()> {
        let ip_a = try!(self.ports.recv("input"));

        let _ = self.ports.send_action("output", ip_a);

        Ok(())
    }
}
